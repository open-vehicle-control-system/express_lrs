# ExpressLrs

Receive-only MAVLink v2 telemetry over UART, shaped as a supervised
Elixir app. Intended for reading MAVLink-framed messages emitted by an
ExpressLRS radio (or any peer speaking MAVLink v2) from an OVCS
firmware.

## Why

ExpressLRS handsets / modules pass through MAVLink telemetry from the
vehicle-side flight controller. OVCS firmwares (VMS, bridges) need to
consume that stream — RSSI, link quality, heartbeat, arming state, etc.
— without pulling in a Python- or C-based ground-station stack. This
library is the narrow piece that:

1. Reads bytes from a UART (`Circuits.UART`).
2. Frames them into MAVLink v2 packets and validates the CRC.
3. Decodes each payload against a `common.xml` dialect loaded at boot.
4. Fan-outs each decoded message to registered listener processes.

Everything upstream (what to *do* with a given message) belongs to the
firmware, not this library.

## Quick start

```elixir
# config/runtime.exs
config :express_lrs,
  enabled: true,
  interface: %{uart_port: "ttyS2", uart_baud_rate: 115_200}
```

```elixir
# any GenServer that wants decoded MAVLink messages
def init(_) do
  ExpressLrs.Mavlink.Interpreter.register_listener(self())
  {:ok, %{}}
end

def handle_cast({:mavlink_message, %MMessage{name: name, base_fields: fields}}, state) do
  # name is a string like "SYSTEM_TIME"; fields is a list of %MField{}
  # whose :value has been populated by the decoder.
  …
end
```

Listeners are monitored — if yours crashes, the Interpreter drops it on
`:DOWN`, so there's nothing to unregister.

With `enabled: false` (the default), the UART connector is not started
and the library is a no-op. Handy for host-side compilation on boxes
without the serial device.

## Supervision tree

```
ExpressLrs.Supervisor  (one_for_one)
├── ExpressLrs.Mavlink.Repository   — loads XML dialect, holds message/enum maps
├── ExpressLrs.Mavlink.Parser       — byte buffer → Frame (incl. CRC check)
├── ExpressLrs.Mavlink.Interpreter  — Frame → decoded MMessage → listeners
└── ExpressLrs.Mavlink.Connector    — Circuits.UART reader (only when :enabled)
```

Data flow: `UART → Connector → Parser.new_bytes/1 → Interpreter.new_frame/1 → listener.cast({:mavlink_message, …})`.

## Dialect loading

At boot, `Repository.init/1` parses `priv/common.xml` via a Saxy
handler. Messages are added keyed by id + name, enums by name; field
lists are reordered by descending wire size to match MAVLink v2's
packing rules, and each message's CRC_EXTRA is computed from the
message name and wire-order fields (CRC-16/X.25 folded to 8 bits).

**Known gap:** `<include>` directives are ignored. `common.xml` pulls
in `minimal.xml` (which defines `HEARTBEAT` id=0 among others) via
`<include>`, so those messages are **not** currently present in the
Repository at runtime. Loading `minimal.xml` explicitly, or teaching
the parser to resolve includes, is tracked as a follow-up.

## Supported MAVLink scalar types

`uint8_t`, `int8_t`, `uint16_t`, `int16_t`, `uint32_t`, `int32_t`,
`uint64_t`, `int64_t`, `float` (32-bit LE IEEE-754), `double` (64-bit
LE IEEE-754), `char` (1-byte binary).

Unknown types are logged at `warn` and skipped (`{nil, 0}`) so a
single unhandled field never crashes the Interpreter.

## Current limitations

Not implemented in this library yet — if you need any of these, treat
them as work items rather than bugs:

- **MAVLink v1** (`0xFE` magic) — only v2 is parsed.
- **MAVLink v2 signing** (13-byte signature when
  `INCOMPAT_FLAGS & 0x01`). Signed frames will desync the parser.
- **Extension fields** — v2-only fields appended after the CRC-covered
  payload are not surfaced on the decoded message.
- **Array-typed fields** — `char[N]`, `uint8_t[N]`, etc. hit the
  unknown-type warning path.
- **XML `<include>` resolution** — see the dialect-loading note above.
- **Transmit** — no frame builder, no `UART.write`, no HEARTBEAT
  emitter. This is a receive-only library today.
- **Parser buffer cap** — on a noisy line the incoming byte buffer has
  no upper bound.
- **Sequence-number tracking** — `SEQ` is parsed but packet-loss
  metrics aren't computed.

## Layout

```
lib/
  express_lrs.ex                          — module shell
  express_lrs/application.ex              — supervision tree
  express_lrs/mavlink/
    repository.ex                         — message/enum maps
    parser.ex                             — byte → Frame, CRC check, stats
    interpreter.ex                        — Frame → MMessage, listener fan-out
    connector.ex                          — Circuits.UART glue
    frame.ex                              — %Frame{} + CRC helpers
    definition/parser.ex                  — Saxy handler for MAVLink XML
    definition/{m_message,m_enum,m_field,m_entry,m_description,m_generic,m_param}.ex
priv/
  common.xml                              — MAVLink common dialect
  minimal.xml                             — MAVLink minimal dialect (not loaded, see above)
  standard.xml                            — placeholder
```

## Dependencies

- `circuits_uart` — UART reader for the Connector.
- `crc` — CRC-16/MCRF4XX (frame checksum) and CRC-16/X.25 (CRC_EXTRA).
- `saxy` — pure-Elixir SAX XML parser for the dialect files.
