import argparse
import json
import math
import random
import socket
import time
from datetime import datetime, timezone
from typing import Dict, NamedTuple, Sequence, Tuple

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 54431
MIN_GROUPS = 20
MIN_SIGNALS_TOTAL = 500
DEFAULT_HZ = 50.0
DEFAULT_LOG_INTERVAL = 5.0
DEFAULT_SEED = 1337

TAU = 2.0 * math.pi


class SignalSpec(NamedTuple):
    name: str
    base_freq: float
    amplitude: float
    phase: float
    noise: float


SignalPlan = Sequence[Tuple[str, Tuple[SignalSpec, ...]]]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate UDP telemetry at 50Hz for >=500 signals without batching, "
            "sending each group immediately for stress testing."
        )
    )
    parser.add_argument("--host", default=DEFAULT_HOST, help="UDP host to send data to")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="UDP port")
    parser.add_argument(
        "--groups",
        type=int,
        default=MIN_GROUPS,
        help="Number of signal groups (min 20)",
    )
    parser.add_argument(
        "--signals-per-group",
        type=int,
        default=math.ceil(MIN_SIGNALS_TOTAL / MIN_GROUPS),
        help="Signals per group (auto-raised so total >= 500)",
    )
    parser.add_argument(
        "--hz",
        type=float,
        default=DEFAULT_HZ,
        help="Target frame rate in Hertz",
    )
    parser.add_argument(
        "--log-interval",
        type=float,
        default=DEFAULT_LOG_INTERVAL,
        help="Seconds between progress logs",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=DEFAULT_SEED,
        help="Random seed for deterministic signal characteristics",
    )
    return parser.parse_args()


def build_signal_plan(groups: int, signals_per_group: int, seed: int) -> SignalPlan:
    groups = max(groups, MIN_GROUPS)
    min_per_group = math.ceil(MIN_SIGNALS_TOTAL / groups)
    signals_per_group = max(signals_per_group, min_per_group)

    rng = random.Random(seed)
    plan = []

    for group_idx in range(groups):
        group_name = f"group_{group_idx:02d}"
        signals = []
        for signal_idx in range(signals_per_group):
            signal_name = f"sig_{group_idx:02d}_{signal_idx:03d}"
            base_freq = rng.uniform(0.05, 3.0)  # Hz
            amplitude = rng.uniform(0.5, 5.0)
            phase = rng.uniform(0.0, TAU)
            noise = rng.uniform(0.01, 0.15)
            signals.append(SignalSpec(signal_name, base_freq, amplitude, phase, noise))
        plan.append((group_name, tuple(signals)))
    return tuple(plan)


def run_sender(args: argparse.Namespace) -> None:
    if args.hz <= 0:
        raise ValueError("--hz must be positive")
    if args.log_interval <= 0:
        raise ValueError("--log-interval must be positive")

    plan = build_signal_plan(args.groups, args.signals_per_group, args.seed)
    groups = len(plan)
    signals_per_group = len(plan[0][1]) if plan else 0
    total_signals = groups * signals_per_group

    noise_rng = random.Random(args.seed ^ 0xABCDEF)
    interval = 1.0 / args.hz
    next_tick = time.perf_counter()
    start_time = next_tick
    last_log = next_tick
    seq = 0
    datagrams_sent = 0

    print(
        f"Streaming telemetry to {args.host}:{args.port} at {args.hz:.1f}Hz"
        f" ({groups} groups x {signals_per_group} signals = {total_signals} signals/frame)"
    )

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        try:
            while True:
                now = time.perf_counter()
                wait = next_tick - now
                if wait > 0:
                    time.sleep(min(wait, 0.001))
                    continue

                timestamp = datetime.now(tz=timezone.utc).timestamp()
                elapsed = seq / args.hz

                for group_name, signals in plan:
                    payload: Dict[str, float] = {}
                    for spec in signals:
                        value = spec.amplitude * math.sin(TAU * spec.base_freq * elapsed + spec.phase)
                        value += noise_rng.uniform(-spec.noise, spec.noise)
                        payload[spec.name] = value
                    payload["frame"] = seq

                    packet = {
                        "type": group_name,
                        "timestamp": timestamp,
                        "data": payload,
                    }
                    datagram = json.dumps(packet, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
                    sock.sendto(datagram, (args.host, args.port))
                    datagrams_sent += 1
                    print(f"send packets {datagrams_sent}")

                seq += 1
                next_tick += interval
                if next_tick < time.perf_counter() - interval:
                    next_tick = time.perf_counter()

                now = time.perf_counter()
                if now - last_log >= args.log_interval:
                    elapsed_wall = now - start_time
                    frame_rate = seq / elapsed_wall if elapsed_wall > 0 else float("nan")
                    packet_rate = datagrams_sent / elapsed_wall if elapsed_wall > 0 else float("nan")
                    print(
                        f"[{datetime.now().strftime('%H:%M:%S')}] frames={seq} (~{frame_rate:.1f}Hz) "
                        f"packets/sec~{packet_rate:.0f}"
                    )
                    last_log = now
        except KeyboardInterrupt:
            print("\nStopped by user.")


def main() -> None:
    args = parse_args()
    run_sender(args)


if __name__ == "__main__":
    main()
