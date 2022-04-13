import fs from "fs"
import cp from "child_process"
import { fatalError, sourcePath } from "./utils"


// TODO:
//   1. parse all test code and extract marked sections: //start:name to //end:name
//   2. remove code indentation (require spaces only, fatal error on tabs)
//   3. insert code snippet into docs (fatal error if no matching snippet)
//   4. fatal error if unused snippet

const getCodeSnippets = () => {
    const result: Record<string, string> = {}
    let testGlob = sourcePath("Tests/**/*.swift")
    let source = cp.execSync(`cat ${testGlob}`, { encoding: "utf8" }).replace(/\r\n/g, "\n")
    let matches = [...source.matchAll(/\/\/\/\s?start:([\w-]+)\n((?:[\s\S](?!\/\/\/))+)\n[ \t]*\/\/\/\s?end/g)]
    for (const [_, name, code] of matches) {
        result[name] = code
    }
    return result
}

console.log(getCodeSnippets())

const compile = () => {
    const readmePath = sourcePath("README.md")
    const content = fs.readFileSync(readmePath, "utf8")
    let replaced = 0
    const compiledContent = content.replace(/(<!---([\w-]+)--->\s*\n```swift\n)((?:[\s\S](?!```))+)(\n```)/mg, (match, prefix, name, code, suffix) => {
        ++replaced
        if (code.includes("<!") || code.includes("->")) fatalError(`Code block includes comment marker:\n${match}`)
        if (code.includes("```")) fatalError(`Code block includes block marker:\n${match}`)
        return prefix + "replaced" + suffix
    })
    
    let specialMarkerCount = content.match(/(<!|->|```)/g)?.length || 0
    if (replaced != specialMarkerCount / 4) fatalError(`Sanity check failed: replaced (${replaced}) != specialMarkerCount (${specialMarkerCount}) / 4`)
    
    console.log(compiledContent)
}



// fs.writeFileSync(readmePath, compiledContent, "utf8")

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

