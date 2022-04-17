import fs from "fs";
import cp from "child_process";
import { fatalError, sourcePath } from "./utils";

// TODO:
//   1. parse all test code and extract marked sections: //start:name to //end:name
//   2. remove code indentation (require spaces only, fatal error on tabs)
//   3. insert code snippet into docs (fatal error if no matching snippet)
//   4. fatal error if unused snippet

const getCodeSnippets = () => {
  const result: Record<string, string> = {};
  let source = cp
    .execSync(
      `cat ${sourcePath("Tests/*/*.swift")} ${sourcePath("Tests/*/*/*.swift")}`,
      { encoding: "utf8" }
    )
    .replace(/\r\n/g, "\n");
  let matches = [
    ...source.matchAll(
      /\/\/\s?docs:start:([\w-]+)\n([\s\S]+?)\n[ \t]*\/\/\s?docs:end/g
    ),
  ];
  for (const [_, name, code] of matches) {
    if (result[name]) {
      fatalError(`Duplicate block names "${name}"`);
    }
    const matches = [...code.matchAll(/(\/\/\s?doc|docs?:).*/g)].map(
      (item) => item[0]
    );
    if (matches.length > 0) {
      fatalError(
        `"${name}" block includes doc markers: ${matches
          .map((s) => JSON.stringify(s))
          .join(", ")}`
      );
    }
    result[name] = removeIndentation(code);
  }
  return result;
};

const removeIndentation = (block: string) => {
  const lines = block.split("\n");
  const prefix = lines[0].replace(/\S.*/, "");
  return lines
    .map((line, i) => {
      if (line && !line.startsWith(prefix)) {
        fatalError(
          `Line ${i + 1} does not start with common prefix ${JSON.stringify({
            prefix,
            line,
          })}:\n${block}`
        );
      }
      return line.substring(prefix.length);
    })
    .join("\n");
};

const compile = () => {
  let codeSnippets = getCodeSnippets();
  const readmePath = sourcePath("README.md");
  const content = fs.readFileSync(readmePath, "utf8");
  let replaced = 0;
  const compiledContent = content.replace(
    /(<!---([\w-]+)--->\s*\n```swift\n)((?:[\s\S](?!```))+)(\n```)/gm,
    (match, prefix, name, code, suffix) => {
      ++replaced;
      if (code.includes("<!") || code.includes("->")) {
        fatalError(`Code block includes comment marker:\n${match}`);
      }
      if (code.includes("```")) {
        fatalError(`Code block includes block marker:\n${match}`);
      }
      if (!codeSnippets[name]) fatalError(`No code snippet "${name}"`);
      return prefix + codeSnippets[name] + suffix;
    }
  );

  let specialMarkerCount = content.match(/(<!|->|```)/g)?.length || 0;
  if (replaced != specialMarkerCount / 4)
    fatalError(
      `Sanity check failed: replaced (${replaced}) != specialMarkerCount (${specialMarkerCount}) / 4`
    );

  fs.writeFileSync(readmePath, compiledContent, "utf8");
  console.log(`Updated ${replaced} blocks in ${readmePath}`);
};

compile();

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
