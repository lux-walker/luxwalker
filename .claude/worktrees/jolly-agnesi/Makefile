dev-server:
	cd app/server && watchexec -r -e gleam -- gleam run

dev-client:
	cd app/client && gleam run -m lustre/dev start

build:
	cd app/client && gleam run -m lustre/dev build --minify
