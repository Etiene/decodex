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

return M
