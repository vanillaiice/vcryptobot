module parse_stop_after

import time

fn test_parse() ! {
  assert parse('0s')! == StopAfter{}
  assert parse('10s')! == StopAfter{10 * time.second, .time}
  assert parse('10m')! == StopAfter{10 * time.minute, .time}
  assert parse('10h')! == StopAfter{10 * time.hour, .time}
  assert parse('10d')! == StopAfter{10 * time.hour * 24, .time}
  assert parse('10t')! == StopAfter{10, .tx}
  assert parse('10x') or { StopAfter{1, .tx} } == StopAfter{1, .tx}
  assert parse('tt') or { StopAfter{1, .tx} } == StopAfter{1, .tx}
}
