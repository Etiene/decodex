-- deps: Torch and Image
local M = {
  gaussians = {}
}

local image = require 'image'

-- img: image Tensor
-- color: {r: <0-255>, g: <0-255>, b: <0-255>}
function M.fill_color(img, color)
	img[1]:fill(color.r)
	img[2]:fill(color.g)
	img[3]:fill(color.b)
end

-- base_img: image Tensor
-- overlay_img: image Tensor
-- x and y: (optional) numbers coordinates of where to start pasting image
function M.overlay_image(base_img, overlay_img, x, y)
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

-- noise_level: number
function M.add_noise(img, noise_level)
	for i = 1,3 do
		img[i] = img[i] + noise_level
	end
end

-- gaussian_level: number
function M.blur(img, gaussian_level)
  local gaussian = M.gaussians[gaussian_level]
  if not gaussian then
    gaussian = image.gaussian(i)
    M.gaussians[gaussian_level] = gaussian
  end

  local img = image.convolve(img, gaussian, 'valid')
  return image.toDisplayTensor{input = img, saturate = true}
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
	M.fill_color(new_img, first_pixel_rgb)
	M.overlay_image(new_img, image, padding_x, paddding_y, size)

	return new_img
end

return M
