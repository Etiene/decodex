local Image = require 'image'
local lfs = require 'lfs'

local M = {
	n_classes = 0
}

torch.setdefaulttensortype('torch.FloatTensor')

local function load_images(dir)
	local images = {}
	for file in lfs.dir(dir) do
		if file ~= '.' and file ~= '..' then
			local image = Image.load(dir..'/'..file, 3)
			local _, _, prefix = string.find(file,'([^.]*).png')
			--print(file)
			images[prefix] = image
		end
	end
	return images -- , n_sample_dirs
end

local function new_image_settings(current_x, current_y)
	local bigger_side = current_x > current_y and current_x or current_y
	local padding = math.abs(current_x - current_y)/2
	padding = current_x > current_y and {0,padding} or {padding,0}
	return bigger_side, padding[0], padding[1]
end

local function image_fill_color(img, color)
	img[1]:fill(color.r)
	img[2]:fill(color.g)
	img[3]:fill(color.b)
end

local function paste_image(base_img, overlay_img, x, y)
	x = x or 0
	y = y or 0
	local size = overlay_img:size()

	for i=1,3 do
		for j=1,size[2] do
			for k=1, size[3] do
				base_img[i][j+x][k+y] = overlay_img[i][j][k]
			end
		end
	end
end

function M.reshape_square(image)
	local size = image:size()
	if size[2] == size[3] then return image end

	local first_pixel_rgb = {r = image[1][1][1], g = image[2][1][1], b = image[3][1][1]}
  local bigger_side, padding_x, paddding_y = new_image_settings(size[2], size[3])

	local new_img = torch.Tensor(3,bigger_side,bigger_side)
	image_fill_color(new_img, first_pixel_rgb)
	paste_image(new_img, image, padding_x, paddding_y)

	return new_img
end

local function do_rotations(image, prefix, size, dir)
	local images = {}
	local m_1 = size[3]*1.3
	local m_2 = size[2]*0.75
	local n = 0

	for i=0.02, 0.10, 0.02 do
		n = n + 1
		local img = Image.rotate(image,i)
		img = Image.crop(img, 'c', math.floor(size[3]-(i*m_1)), math.floor(size[2]-(i*m_2)))
		local pfx = prefix..'_r_'..n
		images[pfx] = img
		Image.save(dir..'/'..pfx..'.png', img)
	end

	for i=-0.10, -0.02, 0.02 do
		n = n + 1
		local img = Image.rotate(image,i)
		img = Image.crop(img, 'c', math.floor(size[3]-(math.abs(i*m_1))), math.floor(size[2]-math.abs((i*m_2))))
		local pfx = prefix..'_r_'..n
		images[pfx] = img
		Image.save(dir..'/'..pfx..'.png', img)
	end
	return images
end

local function do_noise(image, prefix, size, dir)
	local images = {}
	local img = image:clone()
	local noises = {
		torch.rand(size[2],size[3])/2,
		torch.randn(size[2],size[3])/7,
		torch.randn(size[2],size[3])/5
	}
	local n = 0
	for _, noise in ipairs(noises) do
		n = n+1
		for i=1,3 do
			img[i] = image[i] + noise
		end
		local pfx = prefix..'_n_'..n
		images[pfx] = img
		Image.save(dir..'/'..pfx..'.png', img)
	end
end

local function do_blurs(image, prefix, dir)
	local images = {}
	for i = 1, 3 do
		local gau = Image.gaussian(i)
		local img = Image.convolve(image, gau, 'valid')
		local img2 = Image.toDisplayTensor{input = img, saturate = true}
		local pfx = prefix..'_b_'..i
		images[pfx] = img2
		Image.save(dir..'/'..pfx..'.png', img2)
	end
	return images
end

function M.clean_dir(dir)
	os.execute('rm '..dir..'/.DS_Store')
	for file in lfs.dir(dir) do
		local find = string.find(file,'_')
		if find and find > 0  then
			--print(file)
			os.execute('rm '..dir..'/'..file)
		end
	end
	os.execute('rm -rf test')
	os.execute('mkdir test')
end

function M.split_samples()
	local path = 'samples'
	for dir in lfs.dir(path) do
		if dir ~= '.' and dir ~= '..' and dir ~= '.DS_Store' then
			os.execute('mkdir -p test/'..dir)
			for file in lfs.dir(path..'/'..dir) do
				if file ~= '.' and file ~= '..' and file ~= '.DS_Store' then
					local find = string.find(file,'_')
					local r = math.random(10)
					if r < 3 and find and find > 0 then
						os.execute('mv '..path..'/'..dir..'/'..file..' test/'..dir..'/'..file)
					end
				end
			end
		end
	end
end

local function do_resize(image, prefix, size, dir)
	image = Image.scale(image,size,size)
	Image.save(dir..'/'..prefix..'.png',image)
end

function M.run()
	local path = 'samples'
	M.n_classes = 0
	for dir in lfs.dir(path) do
		if dir ~= '.' and dir ~= '..' and dir ~= '.DS_Store' then
			M.n_classes = M.n_classes + 1
			local size

			dir = path..'/'..dir
			M.clean_dir(dir)

			local images = load_images(dir)

			for prefix, image in pairs(images) do
				image = M.reshape_square(image)
				Image.save(dir..'/'..prefix..'.png',image)
				size = Image.getSize(dir..'/'..prefix..'.png')
				do_rotations(image, prefix, size, dir)
			end

			images = load_images(dir)

			for prefix, image in pairs(images) do
				do_blurs(image, prefix, dir)
				size = Image.getSize(dir..'/'..prefix..'.png')
				do_noise(image, prefix, size, dir)
			end

			images = load_images(dir)
			for prefix, image in pairs(images) do
				do_resize(image, prefix, 60, dir)
			end
		end
	end
	M.split_samples()
end

return M
