module parse_stop_after

import time

enum StopAfterType {
  time
  tx
}

struct StopAfter {
  t f64
  stop_after_type StopAfterType
}

pub fn parse(str string) ! StopAfter {
  time_format := [str[str.len - 1]].bytestr()
  time_string := str[0..str.len -1]
  if time_string == '0' { return StopAfter{} }
  timef64 := time_string.f64()
  if timef64 == 0 { return error('invalid string "${str}"') }
  
  match time_format {
    's' {
      return StopAfter{timef64 * time.second, .time}
    }
    'm' {
      return StopAfter{timef64 * time.minute, .time}    
    }
    'h' {
      return StopAfter{timef64 * time.hour, .time}
    }
    'd' {
      return StopAfter{timef64 * time.hour * 24, .time}
    }
    't' {
      return StopAfter{timef64, .tx}
    }
    else { 
      return error('no match for "${time_format}" format') 
    }
  }
}
