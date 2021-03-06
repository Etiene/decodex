local lfs = require 'lfs'
local image = require 'image'
local nn = require 'nn'
local image_util = require 'utils.image'

local M = {
	training_dir = 'samples_training2',
	test_dir = 'samples_test2',
	image_size = 60,
	dumps = {
		training_set = "training2_set.t7",
		testing_set = "testing2_set.t7",
		model = "model2.t7"
	}
}

local function load_images(path)
	local data = { images = {}, labels = {}}
	for dir in lfs.dir(path) do
		if dir:sub(1,1) ~= '.' then
			for file in lfs.dir(path..'/'..dir) do
				if file:sub(1,1) ~= '.' then
					data.images[#data.images+1] = image.load(path..'/'..dir..'/'..file, 3)
					data.labels[#data.labels+1] = dir
				end
			end
		end
	end
	return data
end

local function table_to_tensor(data)
	local joint_images = torch.Tensor(#(data.images), 3, M.image_size, M.image_size)

	for i=1,#data.images do
		joint_images[i]:copy(data.images[i])
	end

	data.images = joint_images
	data.labels = torch.Tensor(data.labels)

	return data
end

local function compute_sets()
	print("Loading sets from images...")
	local training_set = load_images(M.training_dir)
	local testing_set = load_images(M.test_dir)

	training_set = table_to_tensor(training_set)
	testing_set = table_to_tensor(testing_set)

	M.add_meta_ops(training_set)
	M.add_meta_ops(testing_set)
	M.normalize_sets(training_set, testing_set)

	return training_set, testing_set
end

function M.load()
	if not M.training_set or not M.testing_set then
		if not M.load_sets() then
			M.training_set, M.testing_set = compute_sets()
		end
	end
end

function M.add_meta_ops(dataset)
	setmetatable(dataset,
	    {__index = function(t, i)
	    		if i ~= 'images' and i ~= 'labels' then
          	return {t.images[i], t.labels[i]}
          end
          return t[i]
      end}
	)

	function dataset:size()
	  return self.images:size(1)
	end
end


local function calc_means(dataset)
	M.mean = {} -- store the mean, to normalize the test set in the future
	for i=1,3 do -- over each image channel
	    M.mean[i] = dataset.images[{ {}, {i}, {}, {}  }]:mean()
	end
	return M.mean
end

local function calc_std_deviation(dataset)
	M.stdv  = {} -- store the standard-deviation for the future
	for i=1,3 do -- over each image channel
			M.stdv[i] = dataset.images[{ {}, {i}, {}, {}  }]:std() -- std estimation
	end
	return M.stdv
end

local function normalize_set(dataset)
	for i=1,3 do
    dataset.images[{ {}, {i}, {}, {}  }]:add(-M.mean[i]) -- mean subtraction
    dataset.images[{ {}, {i}, {}, {}  }]:div(M.stdv[i]) -- std scaling
	end
end

function M.normalize_sets(training_set, test_set)
	print("Normalising sets...")
	-- both the training and the test sets need to be normalised over
	-- the training set mean and std deviation, apparently
	calc_means(training_set)
	calc_std_deviation(training_set)
	normalize_set(training_set)
	normalize_set(test_set)

	return training_set, test_set
end

function M.train(set, n_classes, epochs)
	epochs = epochs or 20
	print("Training model...")
	local criterion = nn.ClassNLLCriterion()
	local net = nn.Sequential()
	net:add(nn.SpatialConvolution(3, 6, 5, 5)) -- 3 input image channels, 6 output channels, 5x5 convolution kernel
	net:add(nn.ReLU())                       -- non-linearity
	net:add(nn.SpatialMaxPooling(2,2,2,2))     -- A max-pooling operation that looks at 2x2 windows and finds the max.
	net:add(nn.SpatialConvolution(6, 60, 5, 5))
	net:add(nn.ReLU())                       -- non-linearity
	net:add(nn.SpatialMaxPooling(2,2,2,2))
	net:add(nn.View(60*12*12))                    -- reshapes from a 3D tensor of 16x5x5 into 1D tensor of 16*5*5
	net:add(nn.Linear(60*12*12, 120))             -- fully connected layer (matrix multiplication between input and weights)
	net:add(nn.ReLU())                       -- non-linearity
	net:add(nn.Linear(120, 84))
	net:add(nn.ReLU())                       -- non-linearity
	net:add(nn.Linear(84, n_classes))                   -- 10 is the number of outputs of the network (in this case, 10 digits)
	net:add(nn.LogSoftMax())                     -- converts the output to a log-probability. Useful for classification problems

	local trainer = nn.StochasticGradient(net, criterion)
	trainer.learningRate = 0.001
	trainer.maxIteration = epochs -- epochs of training.
	trainer:train(set)
	M.net = net
	return net
end

function M.load_and_normalise(path)
	local img = image.load(path,3)

	for i=1,3 do -- normalize
		img[i]:add(-M.mean[i])
		img[i]:div(M.stdv[i])
	end

	return img
end

local function load_and_prepare_image(path)
	local img = image.load(path,3)
	img = image_util.reshape_square(img)
	img = image.scale(img, M.image_size, M.image_size)

	for i=1,3 do -- normalize
		img[i]:add(-M.mean[i])
		img[i]:div(M.stdv[i])
	end

	return img
end

function M.predict(tensor)
	local predictions = M.net:forward(tensor)
	local confidences, indices = torch.sort(predictions, true)
	confidences = confidences:exp()
	return {confidences, indices}
end

function M.classify_image(path)
	local img = load_and_prepare_image(path)
	local confidences, indices = table.unpack(M.predict(img))

	return indices[1]..': '..confidences[1], confidences, indices
end

function M.verify()
	local correct = 0
	for i=1,M.testing_set:size() do
    local groundtruth = M.testing_set.labels[i]
    local prediction = M.net:forward(M.testing_set.images[i])
    local confidences, indices = torch.sort(prediction, true)  -- true means sort in descending order
    if groundtruth == indices[1] then
        correct = correct + 1
    end
	end
	print(correct, 'correct classifications out of ', M.testing_set:size(), 'samples')
end

function M.run(n_classes, epochs)
	n_classes = n_classes or 2
	M.load()
	local net = M.train(M.training_set, n_classes, epochs)
	return net
end

function M.dump_sets()
	torch.save(M.dumps.testing_set, M.testing_set)
	torch.save(M.dumps.training_set, {M.training_set,M.mean,M.stdv})
	torch.save(M.dumps.model, M.net)
end

function M.load_sets() -- the sets are stored already normalised, but they loose meta info
	for _,v in pairs(M.dumps) do
		if not path.exists(v) then return false end
	end
	M.testing_set = torch.load(M.dumps.testing_set)
	M.training_set,M.mean,M.stdv = table.unpack(torch.load(M.dumps.training_set))
	M.add_meta_ops(M.training_set)
	M.add_meta_ops(M.testing_set)
	M.net = torch.load(M.dumps.model)
	return true
end

return M
