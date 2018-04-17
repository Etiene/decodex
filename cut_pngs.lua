local Image = require 'image'
local lfs = require 'lfs'


for file in lfs.dir('book') do
  if file:sub(1,1) ~= '.' then
    local img = Image.load('book/'..file,3)
--    local size = img:size()
    img = img[{{},{1,240},{}}]
    Image.save('cut_images/'..file,img)
  end
end
