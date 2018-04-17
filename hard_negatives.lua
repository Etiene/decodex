local s = dofile("new_sliding.lua")
local Image = require 'image'


local lfs = require 'lfs'

local function strength_sorting(a,b) return a[1] > b[1] end

print"?"
for file in lfs.dir('hardnegatives/2') do
  if file:sub(1,1) ~= '.' then
    print("Handling ",file)
    s.run('hardnegatives/2/'..file)
    a = table.sort(s.hard_negatives,strength_sorting)
    --print(a)
    for k,v in ipairs(s.hard_negatives) do
      --print(v[1])
      if v[1] > 0.7 then
        Image.save('hardnegatives/out/2/neg_2_2_'..k..'_'..file,v[2])
      end
    end
    s.hard_negatives = {}
  end
end
