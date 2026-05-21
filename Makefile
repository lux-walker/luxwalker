dev-server:
	cd app/server && watchexec -r -e gleam -- gleam run

dev-client:
	cd app/client && gleam run -m lustre/dev start

build:
	cd app/client && gleam run -m lustre/dev build --minify

kill-dev:
	@echo "Killing dev server (port 8080) and client (port 1234) processes..."
	-@pkill -9 -f "watchexec -r -e gleam"
	-@pkill -9 -f "lustre/dev start"
	-@pkill -9 -f "app/server/build/dev/erlang/server"
	-@pkill -9 -f "app/client/build/dev/erlang/client"
	-@pkill -9 -f "lustre_dev_tools/priv/bun-watcher"
	@echo "Done."
