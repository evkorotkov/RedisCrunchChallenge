rockspec_format = "3.0"
package = "luajit"
version = "dev-1"
source = {
  url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
  homepage = "*** please enter a project homepage ***",
  license = "*** please specify a license ***"
}
dependencies = {
  "lua >= 5.1, < 5.5",
  "inspect >= 3.1",
  "lua-cjson >= 2.1",
  "lua-hiredis-with-5.2-fix >= 0.2",
  "openssl >= 0.8"
}
build = {
  type = "builtin",
  modules = {
    setup = "setup.lua",
    main = "main.lua"
  }
}
