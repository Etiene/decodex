local s = dofile("new_sliding.lua")

local lfs = require 'lfs'

local count = 0
for file in lfs.dir('cut_images') do
  if file:sub(1,1) ~= '.' then
    count = count+1
    s.run('cut_images/'..file, count)
  end
end
