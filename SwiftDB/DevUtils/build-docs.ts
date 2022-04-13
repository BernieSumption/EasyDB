import fs from "fs"
import { fatalError, markerName, sourceFile as sourcePath } from "./utils"

const readmePath = sourcePath("README.md")

const content = fs.readFileSync(readmePath, "utf8")

content.replace(/<!---([\w-]+)--->\s*\n```swift\n((?:[\s\S](?!```))+)\n```/mg, (match, name, code) => {
    if (code.includes("<!") || code.includes("->")) fatalError(`Code block includes comment marker:\n${match}`)
    if (code.includes("```")) fatalError(`Code block includes block marker:\n${match}`)
    
    console.log("!!!", name)
    console.log("???", code)
    return ""
})

// let marker: string | undefined

// for (let i = 0; i < lines.length; ++i) {
//     const line = lines[i]
//     const lineMarker = markerName(line)
//     if (lineMarker) {
//         ++i
//         if (lines[i] !== "```swift") fatalError(`Expected start of code block at line ${i+1} got "${lines[i]}"`)
//         ++i
//         let code = ""
//         const firstCodeLine = i
//         while (true) {
//             if (lines[i].trim() !== "```") {
//                 code += lines[i] + "\n"
//             } else {
//                 const lastCodeLine
//             }
//         }
//     }
// }

