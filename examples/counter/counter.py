"""A hit counter that several threads share. The lock makes read-then-write one step."""
import threading

count = 0
lock = threading.Lock()


def hit():
    global count
    with lock:
        seen = count
        count = seen + 1


if __name__ == "__main__":
    threads = [threading.Thread(target=hit) for _ in range(8)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert count == 8, count
    print(count)
