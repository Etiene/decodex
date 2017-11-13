local Image = require 'image'
local lfs = require 'lfs'

local M = {
	n_classes = 0,
	in_dir = 'image_samples',
	out_dir = 'training_images',
	test_dir = 'test_images',
	reshape_size = 60
}

torch.setdefaulttensortype('torch.FloatTensor')

local function load_images(dir)
	local images = {}
	for file in lfs.dir(dir) do
		if file ~= '.' and file ~= '..' then
			local image = Image.load(dir..'/'..file, 3)
			local _, _, filename = string.find(file,'([^.]*).png')
			images[filename] = image
		end
	end
	return images
end

local function new_image_settings(current_x, current_y)
	local bigger_side = current_x > current_y and current_x or current_y
	local padding = math.abs(current_x - current_y)/2
	padding = current_x > current_y and {0,padding} or {padding,0}
	return bigger_side, padding[1], padding[2]
end

local function image_fill_color(image, color)
	image[1]:fill(color.r)
	image[2]:fill(color.g)
	image[3]:fill(color.b)
end

local function paste_image(base_img, overlay_img, x, y, size)
	x = x or 0
	y = y or 0
	local size = size or overlay_img:size()

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

	local new_img = torch.Tensor(3, bigger_side, bigger_side)
	image_fill_color(new_img, first_pixel_rgb)
	paste_image(new_img, image, padding_x, paddding_y, size)

	return new_img
end

local function save_image(images, image, out_path, filename)
	images[filename] = image
	Image.save(out_path..'/'..filename..'.png', image)
end

local function rotate_distort_and_crop(images, image, filename, tag, rotation_settings, out_path)
	local size = image:size()
	local m_1 = size[3] * 1.3
	local m_2 = size[2] * 0.75

	local start, stop, step = table.unpack(rotation_settings)
	local n = 0
	for i = start, stop, step do
		n = n + 1
		local img = Image.rotate(image, i)
		img = Image.crop(img, 'c', math.floor(size[3] - math.abs(i * m_1)), math.floor(size[2] - math.abs(i * m_2)))
		save_image(images, img, out_path, filename..tag..n)
	end
end

local function do_rotations(image, filename, out_path)
	local rotated_images = {}
	local clockwise_rotate = {0.02, 0.10, 0.02}
	local anticlock_rotate = {-0.10, -0.02, 0.02}

	rotate_distort_and_crop(rotated_images, image, filename, '_cwr_', clockwise_rotate, out_path)
	rotate_distort_and_crop(rotated_images, image, filename, '_acwr_', anticlock_rotate, out_path)

	return rotated_images
end

local function add_noise(new_image, base_image, noise)
	for i = 1,3 do
		new_image[i] = base_image[i] + noise
	end
end

local function do_noises(image, filename, out_path)
	local images = {}
	local img = image:clone()
	local size = image:size()
	local noises = {
		torch.randn(size[2], size[3])/2,
		torch.randn(size[2], size[3])/7,
		torch.randn(size[2], size[3])/5
	}
	for i, noise in ipairs(noises) do
		add_noise(img, image, noise)
		save_image(images, img, out_path, filename..'_noi_'..i)
	end
	return images
end

local function do_blurs(image, filename, out_path)
	local images = {}
	for i = 1, 3 do
		local gau = Image.gaussian(i)
		local img = Image.convolve(image, gau, 'valid')
		local img2 = Image.toDisplayTensor{input = img, saturate = true}
		save_image(images, img2, out_path, filename..'_blu_'..i)
	end
	return images
end

function M.clean_dirs()
	os.execute('rm -rf '..M.test_dir)
	os.execute('mkdir '..M.test_dir)
	os.execute('rm -rf '..M.out_dir)
	os.execute('mkdir '..M.out_dir)
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

local function reshape_images(out_path, images)
	print "Reshaping images..."
	local reshaped_images = {}
	for filename, image in pairs(images) do
		image = M.reshape_square(image)
		save_image(reshaped_images, image, out_path, filename)
	end
	return reshaped_images
end

local function scale_images(out_path, images)
	print "Scaling images..."
	local scaled_images = {}
	for filename, image in pairs(images) do
		image = Image.scale(image, M.reshape_size, M.reshape_size)
		save_image(scaled_images, image, out_path, filename)
	end
	return scaled_images
end

local function merge_images(images_out, images_in)
	for k, v in pairs(images_in) do
		images_out[k] = v
	end
end

local function rotate_images(out_path, images)
	print "Slightly rotating images..."
	local rotated_images = {}
	for filename, image in pairs(images) do
		merge_images(rotated_images, do_rotations(image, filename, out_path))
	end
	return rotated_images
end

local function blur_images(out_path, images)
	print "Blurring images..."
	local blurred_images = {}
	for filename, image in pairs(images) do
		merge_images(blurred_images, do_blurs(image, filename, out_path))
	end
	return blurred_images
end

local function noise_images(out_path, images)
	print "Adding noise to images..."
	local noised_images = {}
	for filename, image in pairs(images) do
		merge_images(noised_images, do_noises(image, filename, out_path))
	end
	return noised_images
end

function M.run()
	local images = {}
	M.clean_dirs()
	M.n_classes = 0
	for dir in lfs.dir(M.in_dir) do
		if dir ~= '.' and dir ~= '..' and dir ~= '.DS_Store' then -- TODO CHANGE TO GET FIRST CHAR
			print("Processing image class "..M.n_classes)
			M.n_classes = M.n_classes + 1
			local size
			local out_path = M.out_dir..'/'..dir
			os.execute('mkdir '..out_path)

			images = load_images(M.in_dir..'/'..dir)

			images = reshape_images(out_path, images)
			merge_images(images,rotate_images(out_path, images))
			merge_images(images,scale_images(out_path, images))
			merge_images(images,noise_images(out_path, images))
			merge_images(images,blur_images(out_path, images))

		end
	end
	--M.split_samples()
	return images
end

return M
