local image = require "image"
local model = dofile"model.lua"
local M = {
	window_size = 60,
	drawing = nil
}

local scales = {
	0.3
}

function cut_image(img, step)
	print("Slicing image...")
  local size = img:size()
  local classifications = {}
	local otherimg = img:clone()

  for col=1,size[3]-M.window_size,step do
		local cls_row = {}

    for row=1,size[2]-M.window_size,step do
      local row_to = row + M.window_size-1
      local col_to = col + M.window_size-1
      local img_cut = img[{{},{row,row_to},{col,col_to}}]
			img_cut = model.normalize(img_cut:clone())

      cls_row[#cls_row+1] = model.predict(img_cut)
    end

		classifications[#classifications+1] = cls_row
  end

  return classifications
end

local function merge_images(images_out, images_in)
	for _, v in ipairs(images_in) do
		images_out[#images_out+1] = v
	end
end

function M.load_model()
	print("Loading models...")
  model.dumps.model = 'model2.t7'
  model.load_sets()
end

local function build_classification_tensor(classifications)
	local size_x, size_y = #classifications, #(classifications[1])
	print("Building prediction tensor...")
	local tensor_1 = torch.Tensor(size_x, size_y)
	local tensor_2 = torch.Tensor(size_x, size_y)
	for row=1,size_x do
		for col=1,size_y do
			tensor_1[row][col] = classifications[row][col][1][1] -- confidences
			tensor_2[row][col] = classifications[row][col][2][1] -- class
		end
	end

	return tensor_1,tensor_2
end

local function max_pool(tensor_1,tensor_2,window,step)
	local size = tensor_1:size()
	local locations = {}

  for row=1,size[1]-window,step do
    for col=1,size[2]-window,step do
			local cut = tensor_1[{{row,row+window-1},{col,col+window-1}}]

			local _,a = torch.max(cut,2)
			local _,b = torch.max(a,1)
			local idx_row = b[1][1]
			local idx_col = a[idx_row][1]
			local class = tensor_2[idx_row + row - 1][idx_col+col-1]

			locations[#locations+1] = {(idx_row+row-1)*10, (idx_col+col-1)*10, class}
    end
  end
	return locations
end

local function all_locations(cls)
end

function M.run(page_path)
  M.load_model()
  --local img = model.load_and_normalise(page_path)
	local img= image.load(page_path,3,'float')
	local img_orig = image.load(page_path,3)
	M.drawing = img_orig
  local size = img:size()
  local images = {}
	local locations
  local classifications = {}
  for i,scale in ipairs(scales) do
    local scaled_image = image.scale(img,math.floor(scale*size[3]),math.floor(scale*size[2]))
    local cl = cut_image(scaled_image, 10)
		classifications[1] = table.pack(build_classification_tensor(cl))
    --lassifications[i] = classify_images(images)
		locations = max_pool(classifications[1][1], classifications[1][2], 2, 1)
  end
	for i,scale in ipairs(scales) do
		for iloc,loc in ipairs(locations) do
			local x1 = math.floor(loc[1]/scale)
			local y1 = math.floor(loc[2]/scale)
			local x2 = math.floor((loc[1]+60)/scale)
			local y2 = math.floor((loc[2]+60)/scale)
			--image.save('out/'..loc[3]..'/'..iloc..'.png', img_orig[{{},{y1,y2},{x1,x2}}])

			if loc[3] == 1 then
				img = image.drawRect(img, x1, y1, x2, y2, {lineWidth = 2, color = { 255,	0,		0 }})
			end
		end
	end
	image.save('output.png', img)
	return locations, classifications
end


return M
