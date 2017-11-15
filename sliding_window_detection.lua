local image = require 'image'

local M = {}

M.colors = {
	{ 255,	0,		0 }, -- 1 red
	{ 255,	255,	0 }, -- 2 yellow
	{ 255,	0,		255 }, -- 3 purple
	{ 0,		255,	0 }, -- 4 green
	{ 0,		255,	255 }, -- 5 cyan
	{ 0,		0,		255 }, -- 6 blue
	{ 0,		0,		0 } -- 7 black
}

M.detected = {}

local scales = { 
	1.8, 
	1.5, 
	1.2, 
	--1,
	0.8, 
	0.5, 
--	0.3 
}

local function compare(a,b)
  return a.strength > b.strength
end

local function is_overlapping(a,b)
	return  (b.x1 > a.x1 and b.x1 < a.x2) or 
					(a.x1 > b.x1 and a.x1 < b.x2) or
					(b.y1 > a.y1 and b.y1 < a.y2) or 
					(a.y1 > b.y1 and a.y1 < b.y2) 
end

local function overlapping_area(a,b) 
	local bigger_x1 = a.x1 > b.x1 and a.x1 or b.x1
	local smaller_x2 = a.x2 < b.x2 and a.x2 or b.x2

	local bigger_y1 = a.y1 > b.y1 and a.y1 or b.y1
	local smaller_y2 = a.y2 < b.y2 and a.y2 or b.y2

	return (smaller_x2 - bigger_x1) * (smaller_y2 - bigger_y1)
end



function M.compress()
	table.sort(M.detected, compare)

	for i=1,#M.detected do
		if M.detected[i].class == 8 then M.detected[i].weak = true end
	end

	for i=1,#M.detected do
		if not M.detected[i].weak then
			local i_area = (M.detected[i].x2 - M.detected[i].x1) * (M.detected[i].y2 - M.detected[i].y1)

			for j=i+1,#M.detected do
				--local i_area = ??
				local j_area = (M.detected[j].x2 - M.detected[j].x1) * (M.detected[j].y2 - M.detected[j].y1)
				if  not M.detected[j].weak and
						--M.detected[i].class ~= M.detected[j].class and
						is_overlapping(M.detected[i],M.detected[j]) and 
					  (
					  	overlapping_area(M.detected[i],M.detected[j])  >= j_area/2 
					   or overlapping_area(M.detected[i],M.detected[j])  >= i_area*1/4 ) 
						then
					  print('Overlapped')
					  M.detected[j].weak = true
				end
			end
		end
	end
	--for i=1,#M.detected do
		--if M.detected[i].weak then M.detected[i] = nil end
	--end
	return M.detected
end

local function slide_and_detect(network, img, scale, mean, stdv, step)
	
	for i=1,3 do -- over each image channel
    img[i]:add(-mean[i]) -- mean subtraction    
    img[i]:div(stdv[i]) -- std scaling
	end
	local size = img:size()

	for i = 1, size[2]-60-step, step do
		for j = 1, size[3]-60-step, step do
			--print(i,j)
			local view = img[{ {}, {i,i+59}, {j,j+59}}]
			local pred = network:forward(view)
			pred = pred:exp()
			for k=1,pred:size(1) do
				if pred[k]>0.99 and k ~= 8 then
					print('FOUND',pred:size(1),i,j,k,pred[k])
					--image.display(view)
					M.detected[#M.detected + 1] = {class = k, strength = pred[k], view = view, x1 = j/scale, y1 = i/scale, x2 = (j+59)/scale, y2 = (i+59)/scale}
				end
			end
		end
	end

end	

function M.run(network,image_path,mean,stdv,step)
	step = step or 10
	local img = image.load(image_path, 3)
	local img2 = image.toDisplayTensor({input = img, saturate = false, }) 

	local pyramid = image.gaussianpyramid(img, scales)

	slide_and_detect(network, img, 1, mean,stdv, step)
	for i, img in ipairs(pyramid) do
		slide_and_detect(network, img, scales[i], mean,stdv, step)
	end

	M.compress()
	for i=1,#M.detected do
		--if M.detected[i].weak then M.detected[i] = nil
		if not M.detected[i].weak and M.detected[i].class ~= 8 then
			local lw = M.detected[i].strength == 1 and 10 or 2
			img2 = image.drawRect(img2, M.detected[i].x1, M.detected[i].y1, M.detected[i].x2, M.detected[i].y2, {lineWidth = 2, color = M.colors[M.detected[i].class]})
		end
	end
						

	image.display(img2)
end

return M