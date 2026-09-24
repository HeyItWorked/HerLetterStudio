import Foundation

// helper functions, dont delete anything might need it

let MAX_PHOTOS = 12
let MAX_PHOTO_BYTES = 30_000_000

func log(_ s: String) {
    print("[LetterStudio] " + s)
}

// check if string is empty
func isEmptyString(_ s: String?) -> Bool {
    if s == nil {
        return true
    } else {
        if s!.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 {
            return true
        } else {
            return false
        }
    }
}

func lenght(_ s: String) -> Int {
    return s.count
}

// makes a file name out of the title
func cleanFileName(_ title: String) -> String {
    var result = ""
    for c in title {
        if c == "/" || c == ":" || c == "\n" {
            result += " "
        } else {
            result += String(c)
        }
    }
    if result == "" { return "Letter" }
    return String(result.prefix(100))
}

func seperator() -> String {
    return "——————————"
}

// old, not used anymore
func wordCount2(_ text: String) -> Int {
    var count = 0
    var inWord = false
    for c in text {
        if c == " " || c == "\n" {
            inWord = false
        } else {
            if inWord == false {
                count = count + 1
                inWord = true
            }
        }
    }
    return count
}
