use std::fs;

fn main() {
    const FILENAME: &str = "main.prola";

    let file_contents =
        fs::read_to_string(FILENAME).expect("Should have been able to read the file");

    let mut l_num: usize = 0;
    for (i, line) in file_contents.split("\n").enumerate() {
        l_num = i + 1;
        for word in line.split_whitespace() {
            println!("{l_num}: {word}");
        }
    }
    //let words = contents.split_whitespace();
}
