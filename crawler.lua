local http = require 'socket.http'

local urls_queue = {
  'http://etiene.net'
}

local visited = {}

while #urls_queue > 0 do
  if not visited[urls_queue[1]] then
    local body,c,l,h = http.request(urls_queue[1])

    print('status line',l)
    print(c,h)
    print('body',body)

    local resources = {}
    visited[url] = true
  end
  table.remove(urls_queue, 1)
end
