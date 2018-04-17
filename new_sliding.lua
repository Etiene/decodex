local image = require "image"
local model = dofile"model.lua"
local M = {
	window_size = 32,
	drawing = nil,
	hard_negatives = {},
	model_loaded = false
}

local scales = {
	--0.2,
	0.25,
	0.3,
	0.35,
	0.4,
	--0.43,
	0.45,
	--0.5,
	--0.55,
	--1
}

local function build_hard_negatives(prediction, image)
	local confidence = prediction[1][1]
	local class = prediction[2][1]
	if class == 1 then
		M.hard_negatives[#(M.hard_negatives)+1]={confidence, image}
	end
end

local function build_more_samples(prediction, img)
	if prediction[1][1] > 0.9999 and prediction[2][1] == 1 then
		local size = img:size()
		local cut = img[{{},{},{2,size[3]-2}}]
		image.save('1s/gen_'..math.random(1,1000000)..'.png', cut)
	end
end

local function cut_image(img, step)
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
			local cut_clone = img_cut:clone()
			cut_clone = model.normalize(cut_clone)
			local prediction = model.predict(cut_clone)
			--build_hard_negatives(prediction,img_cut)
			--build_more_samples(prediction, img_cut)

      cls_row[#cls_row+1] = prediction
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
	if M.model_loaded then return end
	print("Loading models...")
  model.dumps.model = 'modeltotal.t7'
  model.load_sets()
	M.model_loaded = true
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

local function asas()
	local avgs = {}
	for r=1,window do
		for c=1, window do
			avgs[tensor_2[r + row - 1][c+col-1]] = avgs[tensor_2[r + row - 1][c+col-1]] or {}
			table.insert(avgs[tensor_2[r + row - 1][c+col-1]],cut[r][c])
		end
	end



				for i,list in ipairs(avgs) do
					local sum = 0
					for j,v in ipairs(list) do
						sum = sum + v + 0.0001
					end
					avgs[i] = sum/#(avgs[i])
				end

				for k,v in ipairs(avgs) do
					if v > max then
						max = v
						class = k
					end
				end

end

local function max_pool(tensor_1,tensor_2,window,step,scale)
	local size = tensor_1:size()
	local locations = {}
	print"Max Pooling..."

  for row=1,size[1]-window,step do
    for col=1,size[2]-window,step do
			local cut = tensor_1[{{row,row+window-1},{col,col+window-1}}]
			local max = torch.max(cut)






			local _,a = torch.max(cut,2)
			local _,b = torch.max(a,1)
			local idx_row = b[1][1]
			local idx_col = a[idx_row][1]
			local class = tensor_2[idx_row + row - 1][idx_col+col-1]

			if max > 0.999 and class == 1 then
				local x1 = math.floor(((idx_row+row-2)*2)/scale)
				local y1 = math.floor(((idx_col+col-2)*2)/scale)
				local x2 = math.floor((((idx_row+row-2)*2)+M.window_size)/scale)
				local y2 = math.floor((((idx_col+col-2)*2)+M.window_size)/scale)
				locations[#locations+1] = {{x1=x1,x2=x2,y1=y1,y2=y2},class, max}
			end
    end
  end
	return locations
end

local function all_locations(cls)
end

local function is_overlapping(a,b)
	return  ((b.x1 >= a.x1 and b.x1 <= a.x2) or
					 (b.x2 >= a.x1 and b.x2 <= a.x2)) and
					((b.y1 >= a.y1 and b.y1 <= a.y2) or
					 (b.y2 >= a.y1 and b.y2 <= b.y2))
end

local function overlapping_area(a,b)
	local bigger_x1 = a.x1 > b.x1 and a.x1 or b.x1
	local smaller_x2 = a.x2 < b.x2 and a.x2 or b.x2

	local bigger_y1 = a.y1 > b.y1 and a.y1 or b.y1
	local smaller_y2 = a.y2 < b.y2 and a.y2 or b.y2

	local ratio_1 = ((math.max(0,smaller_x2 - bigger_x1) + 1) * (math.max(0,smaller_y2 - bigger_y1) + 1))/((a.x2-a.x1 + 1)*(a.y2-a.y1 + 1))
	local ratio_2 = ((math.max(0,smaller_x2 - bigger_x1) + 1) * (math.max(0,smaller_y2 - bigger_y1) + 1))/((b.x2-b.x1 + 1)*(b.y2-b.y1 + 1))

	return  ratio_1 > ratio_2 and ratio_1 or ratio_2
end

local function suppress(locations, scale)
	local max_y_sorting = function(a, b) return a[1].y2>b[1].y2 end
	local strength_sorting = function(a, b) if a[3]==b[3] then return a[1].y2>b[1].y2 else return a[3]>b[3] end end
	table.sort(locations, strength_sorting)
	--print(locations)
	local picked = {}
	while #locations > 0 do
		local loc = locations[#locations]
		picked[#picked + 1] = loc
		local suppress={loc}
		for i=1,#locations-1 do
			--print(loc[1], locations[i][1])
			--if is_overlapping(loc[1], locations[i][1]) then
				--print(overlapping_area(loc[1], locations[i][1]) )
				if overlapping_area(loc[1], locations[i][1]) > 0.4 then
					--print(overlapping_area(loc[1], locations[i][1], scale))
					table.insert(suppress,locations[i])
				end
			--end
		end
		for i=1,#suppress do
			for j = 1,#locations do
				if locations[j] == suppress[i] then
					table.remove(locations,j)
				end
			end
		end
	end


	return picked
end

function M.run(page_path, prefix)
	prefix = prefix or ""
  M.load_model()
	local count = 0
  --local img = model.load_and_normalise(page_path)
	local img= image.load(page_path,3,'double')
	local img_orig = image.load(page_path,3)
	M.drawing = img_orig
  local size = img:size()
  local images = {}
	local locations = {}
  local classifications = {}
  for i,scale in ipairs(scales) do
    local scaled_image = image.scale(img,math.floor(scale*size[3]),math.floor(scale*size[2]))
    local cl = cut_image(scaled_image, 2)
		classifications[1] = table.pack(build_classification_tensor(cl))
    --lassifications[i] = classify_images(images)
		local scale_locations = max_pool(classifications[1][1], classifications[1][2], 6, 3, scale)
		for k,v in ipairs(scale_locations) do locations[#locations+1] = v end
  --end
	--for i,scale in ipairs(scales) do



	end
	print"Drawing rectangles..."
	locations = suppress(locations)


	for iloc,loc in ipairs(locations) do
		count = count + 1

		if loc[2] == 1 then
			--image.save('1s/gen_'..prefix..'_'..count..'.png', img_orig[{{},{loc[1].y1,loc[1].y2},{loc[1].x1+5,loc[1].x2-5}}])

			img = image.drawRect(img, loc[1].x1, loc[1].y1, loc[1].x2, loc[1].y2, {lineWidth = 2, color = { 255,	0,		0 }})
		end
	end

	image.save('output.png', img)
	return locations, classifications
end


return M
