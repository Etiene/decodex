local Image = require 'image'
local lfs = require 'lfs'
local image_utils = dofile('utils/image.lua')

local M = {
	n_classes = 0,
	in_dir = 'image_samples',
	in_test_dir = 'image_samples',
	out_dir = 'training_images',
	out_test_dir = 'test_images',
	reshape_size = 60,
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

function M.reshape_square(image)
	local size = image:size()
	if size[2] == size[3] then return image end

	local first_pixel_rgb = {r = image[1][1][1], g = image[2][1][1], b = image[3][1][1]}
  local bigger_side, padding_x, paddding_y = new_image_settings(size[2], size[3])

	local new_img = torch.Tensor(3, bigger_side, bigger_side)
	image_utils.fill_color(new_img, first_pixel_rgb)
	image_utils.overlay_image(new_img, image, padding_x, paddding_y, size)

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

local function do_noises(image, filename, out_path)
	local images = {}
	local img = image:clone()
	local size = image:size()
	local noises = {
		torch.randn(size[2], size[3])/10,
		torch.randn(size[2], size[3])/8,
		torch.randn(size[2], size[3])/5
	}
	for i, noise in ipairs(noises) do
		image_utils.add_noise(img, noise)
		save_image(images, img, out_path, filename..'_noi_'..i)
	end
	return images
end

local function do_blurs(image, filename, out_path)
	local images = {}
	for i = 1, 3 do
		local img = image_utils.blur(image, i)
		save_image(images, img, out_path, filename..'_blu_'..i)
	end
	return images
end

function M.clean_dirs()
	os.execute('rm -rf '..M.out_test_dir)
	os.execute('mkdir '..M.out_test_dir)
	os.execute('rm -rf '..M.out_dir)
	os.execute('mkdir '..M.out_dir)
end

function M.split_samples()
	print "Splitting training and test sets..."
	for dir in lfs.dir(M.out_dir) do
		if dir ~= '.' and dir ~= '..' and dir ~= '.DS_Store' then -- TODO first char
			os.execute('mkdir -p '..M.out_test_dir..'/'..dir)
			for file in lfs.dir(M.out_dir..'/'..dir) do
				if file ~= '.' and file ~= '..' and file ~= '.DS_Store' then
					local find = string.find(file,'_')
					local r = math.random(10)
					if r < 3 and find and find > 0 then
						os.execute('mv '..M.out_dir..'/'..dir..'/'..file..' '..M.out_test_dir..'/'..dir..'/'..file)
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

function M.run_all()
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
			print("Done processing this class")
		end
	end
	M.split_samples()
	return images
end

return M
