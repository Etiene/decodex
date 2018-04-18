local utf8 = require "lua-utf8"

local test_strings = {
  require "pt",
  require "en",
  require "fr",
  require "de",
  require "es",
}

local character_groupings = {
  a = {"à","á","â","ã","ä"},
  e = {"é","è","ê","ë"},
  i = {"í","î","ï"},
  o = {"ó","ô","õ","ö"},
  u = {"ú","ü"},
  c = {"ç"},
  s = {"ß"},
  n = {"ñ"},
}

local character_count_set = {}
local l = 0

for _,test_string in ipairs(test_strings) do
  test_string = utf8.lower(test_string)
  for c_replace,cg in pairs(character_groupings) do
    for _,c in ipairs(cg) do
      test_string = utf8.gsub(test_string, c, c_replace)
    end
  end

  for c in utf8.gmatch(test_string,"%a") do
    character_count_set[c] = (character_count_set[c] or 0) + 1
    l = l + 1
  end
end

local character_count_array = {}
for c,n in pairs(character_count_set) do
  table.insert(character_count_array,{c,n})
end

local function compare(a,b)
  return a[2] > b[2]
end

table.sort(character_count_array, compare)

for _,c in ipairs(character_count_array) do
  print(c[1],string.format("%.2f",c[2]*100/l))
end
