//! The history on disk (provider ids, timestamps and percentages only). A missing file is an
//! empty history; an unreadable one is reported once and replaced by the next save.

use std::collections::BTreeMap;
use std::fs;
use std::io;
use std::path::Path;

use serde_json::Value;

use super::{UsageHistory, UsageSample};

const FILE_NAME: &str = "history.json";
const TEMP_FILE_NAME: &str = "history.json.tmp";
const SAMPLES_KEY: &str = "samples";

impl UsageHistory {
    /// Loads the saved history, dropping samples dated after `now`. Never fails: whatever cannot
    /// be read yields an empty history, and a damaged file is reported once.
    pub fn load(dir: &Path, now: i64) -> Self {
        let Ok(text) = fs::read_to_string(dir.join(FILE_NAME)) else { return Self::default() };
        match parse(&text, now) {
            Ok(history) => history,
            Err(reason) => {
                eprintln!("usage-gauge: ignoring unreadable {FILE_NAME}: {reason}");
                Self::default()
            }
        }
    }

    /// Writes through a temporary file so a crash never leaves half a history behind.
    pub fn save(&self, dir: &Path) {
        if let Err(error) = self.write(dir) {
            eprintln!("usage-gauge: could not save {FILE_NAME}: {error}");
        }
    }

    fn write(&self, dir: &Path) -> io::Result<()> {
        fs::create_dir_all(dir)?;
        let temp = dir.join(TEMP_FILE_NAME);
        fs::write(&temp, serde_json::to_string(self)?)?;
        fs::rename(&temp, dir.join(FILE_NAME))
    }
}

/// Decodes a sample or nothing, so one damaged entry does not cost the whole file.
fn parse(text: &str, now: i64) -> Result<UsageHistory, String> {
    let root: Value = serde_json::from_str(text).map_err(|error| error.to_string())?;
    let stored = root
        .get(SAMPLES_KEY)
        .and_then(Value::as_object)
        .ok_or_else(|| format!("no \"{SAMPLES_KEY}\" object"))?;
    let samples: BTreeMap<String, Vec<UsageSample>> = stored
        .iter()
        .map(|(id, series)| {
            let entries = series.as_array().map_or(&[][..], Vec::as_slice);
            let kept = entries
                .iter()
                .filter_map(|entry| serde_json::from_value::<UsageSample>(entry.clone()).ok())
                .filter(|sample| sample.at <= now)
                .collect();
            (id.clone(), kept)
        })
        .collect();
    Ok(UsageHistory::from_samples(samples))
}
