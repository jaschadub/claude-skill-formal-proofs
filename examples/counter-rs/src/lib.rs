// Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
//! The hit counter of `examples/counter`, in Rust. `VERIFY.md` says how it is checked.
#[cfg(loom)]
use loom::sync::Mutex;
#[cfg(not(loom))]
use std::sync::Mutex;

/// With the `trace` feature, one line for each step of the model, in the order that the steps ran.
#[cfg(feature = "trace")]
static TRACE: std::sync::Mutex<Vec<String>> = std::sync::Mutex::new(Vec::new());

/// Log a step. Call it while the step still holds the lock, or the log can differ from the real order.
macro_rules! trace {
    ($action:literal) => {
        #[cfg(feature = "trace")]
        TRACE.lock().unwrap().push(format!(
            "[action |-> \"{}\", thread |-> \"{}\"]",
            $action,
            std::thread::current().name().unwrap_or("?")
        ));
    };
}

#[derive(Default)]
pub struct Counter {
    count: Mutex<u64>,
}

impl Counter {
    pub fn hit(&self) {
        let mut count = self.count.lock().unwrap();
        trace!("TakeLock");
        let seen = *count;
        trace!("Read");
        *count = seen + 1;
        trace!("Write");
    }

    pub fn get(&self) -> u64 {
        *self.count.lock().unwrap()
    }
}

#[cfg(all(test, not(loom)))]
mod tests {
    #[test]
    fn one_hit_counts() {
        let counter = super::Counter::default();
        counter.hit();
        assert_eq!(counter.get(), 1);
    }
}

/// loom runs the test once for each order in which the two threads can take their steps.
#[cfg(all(test, loom))]
mod every_order {
    use super::Counter;
    use loom::sync::Arc;

    #[test]
    fn no_lost_hit() {
        loom::model(|| {
            let counter = Arc::new(Counter::default());
            let threads: Vec<_> = (0..2)
                .map(|_| {
                    let counter = counter.clone();
                    loom::thread::spawn(move || counter.hit())
                })
                .collect();
            for thread in threads {
                thread.join().unwrap();
            }
            assert_eq!(counter.get(), 2);
        });
    }
}

/// Runs the real code on three threads and writes the log of its steps to the file that TRACE_LOG names.
#[cfg(all(test, feature = "trace", not(loom)))]
mod real_run {
    use super::{Counter, TRACE};
    use std::sync::Arc;

    #[test]
    fn write_trace() {
        let counter = Arc::new(Counter::default());
        let threads: Vec<_> = ["t1", "t2", "t3"]
            .into_iter()
            .map(|name| {
                let counter = counter.clone();
                let thread = std::thread::Builder::new().name(name.into());
                thread.spawn(move || counter.hit()).unwrap()
            })
            .collect();
        for thread in threads {
            thread.join().unwrap();
        }
        let log = std::env::var("TRACE_LOG").expect("set TRACE_LOG to the file to write");
        std::fs::write(log, TRACE.lock().unwrap().join("\n")).unwrap();
    }
}
