local lfs = require 'lfs'
local image = require 'image'
local nn = require 'nn'

local M = {}

function M.load()
	local training = {
		data = {},
		label = {}
	}

	local testing = {
		data = {},
		label = {}
	}

	for dir in lfs.dir('samples') do
		if dir ~= '.' and dir ~= '..' and dir ~= '.DS_Store' then
			for file in lfs.dir('samples/'..dir) do
				if file ~= '.' and file ~= '..' and file ~= '.DS_Store' then
					training.data[#training.data+1] = image.load('samples/'..dir..'/'..file, 3)
					training.label[#training.label+1] = dir
				end
			end
		end
	end

	for dir in lfs.dir('test') do
		if dir ~= '.' and dir ~= '..' and dir ~= '.DS_Store' then
			for file in lfs.dir('test/'..dir) do
				if file ~= '.' and file ~= '..' and file ~= '.DS_Store' then
					testing.data[#testing.data+1] = image.load('test/'..dir..'/'..file, 3)
					testing.label[#testing.label+1] = dir
				end
			end
		end
	end
	local data = torch.Tensor(#training.data,3,60,60)
	for i=1,#training.data do
		data[i]:copy(training.data[i])
	end
	training.data = data
	data = torch.Tensor(#testing.data,3,60,60)
	for i=1,#testing.data do
		data[i]:copy(testing.data[i])
	end
	testing.data = data
	training.label = torch.Tensor(training.label)
	testing.label = torch.Tensor(testing.label)
	return training, testing
end

function M.add_ops(set)
	setmetatable(set, 
	    {__index = function(t, i)
	    		if i ~= 'data' and i ~= 'label' then
          	return {t.data[i], t.label[i]} 
          end
          return t[i]          	
      end}
	)
	--set.data = set.data:double() -- convert the data from a ByteTensor to a DoubleTensor.

	function set:size() 
	  return self.data:size(1) 
	  --return #self.data
	end
end

function M.normalize_sets(train_set, test_set)
	M.mean = {} -- store the mean, to normalize the test set in the future
	M.stdv  = {} -- store the standard-deviation for the future
	for i=1,3 do -- over each image channel
	    M.mean[i] = train_set.data[{ {}, {i}, {}, {}  }]:mean() -- mean estimation
	    print('Channel ' .. i .. ', Mean: ' .. M.mean[i])
	    train_set.data[{ {}, {i}, {}, {}  }]:add(-M.mean[i]) -- mean subtraction
	    
	    M.stdv[i] = train_set.data[{ {}, {i}, {}, {}  }]:std() -- std estimation
	    print('Channel ' .. i .. ', Standard Deviation: ' .. M.stdv[i])
	    train_set.data[{ {}, {i}, {}, {}  }]:div(M.stdv[i]) -- std scaling
	end

	for i=1,3 do -- over each image channel
    test_set.data[{ {}, {i}, {}, {}  }]:add(-M.mean[i]) -- mean subtraction    
    test_set.data[{ {}, {i}, {}, {}  }]:div(M.stdv[i]) -- std scaling
	end
end

function M.verify_outisde_image(path)
	local samples = require 'increase_samples'
	local img = image.load(path,3)
	img = samples.reshape_square(img)
	img = image.scale(img,60,60)

	for i=1,3 do -- over each image channel
    img[i]:add(-M.mean[i]) -- mean subtraction    
    img[i]:div(M.stdv[i]) -- std scaling
	end

	return M.net:forward(img)
end


function M.train(set, n_classes)
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
	trainer.maxIteration = 5 -- just do 5 epochs of training.
	trainer:train(set)
	M.net = net
	return net
end


function M.verify()
	local correct = 0
	for i=1,M.testing_set:size() do
    local groundtruth = M.testing_set.label[i]
    local prediction = M.net:forward(M.testing_set.data[i])
    local confidences, indices = torch.sort(prediction, true)  -- true means sort in descending order
    if groundtruth == indices[1] then
        correct = correct + 1
    end
	end
	print(correct, 'correct classifications out of ', M.testing_set:size(), 'samples')
end

function M.run(n_classes)
	n_classes = n_classes or 2
	local training_set, testing_set = M.load()
	M.add_ops(training_set)
	M.add_ops(testing_set)
	M.normalize_sets(training_set,testing_set)
	local net = M.train(training_set,n_classes)
	
	M.testing_set = testing_set
	return net, testing_set
end	

return M
