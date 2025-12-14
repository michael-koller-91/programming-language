use std::fs;

fn main() {
    const FILENAME: &str = "main.prola";

    let contents = fs::read_to_string(FILENAME).expect("Should have been able to read the file");

    println!("{contents}");
}
