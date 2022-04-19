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

const validateInternalLinks = (content: string) => {
  let links = [...content.matchAll(/]\(#([\w-]+)\)/g)].map((match) => match[1]);
  let linkMarkerCount = [...content.matchAll(/\(#/g)].length;
  if (links.length != linkMarkerCount) {
    fatalError(
      `${links.length} links found but ${linkMarkerCount} link markers ("(#") in docs`
    );
  }

  let headings = [...content.matchAll(/^\s*#+\s*(.+)/gm)].map((match) =>
    match[1].toLowerCase().replace(/\s+/g, "-")
  );

  for (const link of links) {
    let count = headings.filter((heading) => heading === link).length;
    if (count == 0) {
      fatalError(`Internal link #${link} has no matching heading`);
    }
    if (count > 1) {
      fatalError(`Internal link #${link} matches two headings`);
    }
  }
};

const compile = () => {
  let codeSnippets = getCodeSnippets();
  const readmePath = sourcePath("README.md");
  const content = fs.readFileSync(readmePath, "utf8");
  validateInternalLinks(content);
  let replaced = 0;
  const compiledContent = content.replace(
    /(<!---([\w-]+)--->\s*\n```swift)((?:[\s\S](?!```))*)(\n```)/gm,
    (match, prefix, name, code, suffix) => {
      ++replaced;
      if (code.includes("<!") || code.includes("->")) {
        fatalError(`Code block includes comment marker:\n${match}`);
      }
      if (code.includes("```")) {
        fatalError(`Code block includes block marker:\n${match}`);
      }
      if (!codeSnippets[name]) fatalError(`No code snippet "${name}"`);
      return prefix + "\n" + codeSnippets[name] + suffix;
    }
  );

  let specialMarkerCount = content.match(/(<!|->|```)/g)?.length || 0;
  if (replaced != specialMarkerCount / 4) {
    fatalError(
      `Sanity check failed: replaced (${replaced}) != specialMarkerCount (${specialMarkerCount}) / 4`
    );
  }

  let isValidateMode = process.argv.includes("--validate");

  if (isValidateMode) {
    console.log(`✨ docs are valid`);
  } else {
    fs.writeFileSync(readmePath, compiledContent, "utf8");
    console.log(`💫 updated ${replaced} blocks in ${readmePath}`);
  }
};

compile();
