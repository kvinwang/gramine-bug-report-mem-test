use rand::prelude::*;
use std::sync::{Arc, Barrier};
use std::thread;

mod allocator;

fn get_peak() -> (usize, usize) {
    let rust_peak = allocator::ALLOCATOR.stats().peak_used;
    let vm_peak = vm_peak().unwrap_or(0) * 1024;
    (rust_peak, vm_peak)
}

fn vm_peak() -> Option<usize> {
    let status = std::fs::read_to_string("/proc/self/status").ok()?;
    for line in status.lines() {
        if line.starts_with("VmPeak:") {
            let peak = line.split_ascii_whitespace().nth(1)?;
            return peak.parse().ok();
        }
    }
    None
}

fn main() {
    const MAX_SIZE: usize = 8 * 1024 * 1024;
    const THREAD_COUNT: usize = 4;

    let barrier = Arc::new(Barrier::new(THREAD_COUNT));

    for _t in 0..THREAD_COUNT {
        let barrier_clone = barrier.clone();
        thread::spawn(move || {
            barrier_clone.wait();

            let mut prev_peak = (0, 0);
            loop {
                let size = rand::thread_rng().gen_range(0..MAX_SIZE);
                let _buf = vec![1u8; size]; // Allocate memory
                let peak = get_peak();
                let peak_changed = peak != prev_peak;
                if peak_changed {
                    println!("Rust peak: {}, process peak: {}", peak.0, peak.1);
                    prev_peak = peak;
                }
            }
        });
    }
    thread::sleep(std::time::Duration::from_secs(std::u64::MAX));
}
