import os
import time
import socket
import ray


ray.init(address=os.environ["RAY_ADDRESS"], ignore_reinit_error=True)

# Wait until both nodes are visible
while True:
    nodes = [n for n in ray.nodes() if n["Alive"]]
    if len(nodes) >= 2:
        break
    time.sleep(2)

print("\nRay cluster nodes:")
for n in nodes:
    name = n.get("NodeName")
    ip = n.get("NodeManagerAddress")
    print(f"{name}  ({ip})")

@ray.remote
def ping():
    return {
        "hostname": socket.gethostname(),
        "pid": os.getpid()
    }

results = ray.get([ping.remote() for _ in nodes])

print("\nPing results:")
for r in results:
    print(r)

ray.shutdown()