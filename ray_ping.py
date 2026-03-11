import os
import time
import socket
import ray


EXPECTED_RAY_NODES = int(os.environ.get("EXPECTED_RAY_NODES", "2"))

ray.init(address=os.environ["RAY_ADDRESS"], ignore_reinit_error=True)

# Wait until all expected nodes are visible
while True:
    nodes = [n for n in ray.nodes() if n["Alive"]]
    if len(nodes) >= EXPECTED_RAY_NODES:
        break
    time.sleep(2)

print(f"\nRay cluster nodes ({len(nodes)}/{EXPECTED_RAY_NODES} visible):")
for i, n in enumerate(nodes, 1):
    print(
        f"  node {i}: "
        f"ip={n.get('NodeManagerAddress')} "
        f"hostname={n.get('NodeName')} "
        f"alive={n.get('Alive')}"
    )


@ray.remote
def ping():
    return {
        "hostname": socket.gethostname(),
        "ip": socket.gethostbyname(socket.gethostname()),
        "pid": os.getpid(),
    }


results = ray.get([ping.remote() for _ in range(len(nodes))])

print("\nPing results:")
for r in results:
    print(r)

ray.shutdown()