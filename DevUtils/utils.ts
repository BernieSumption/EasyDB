import path from "path"

export const sourcePath = (file: string) => path.join(__dirname, "..", file)

export const markerName = (line: string) => {
    line = line.trim()
    if (line.includes("<!")) {
        const match = (line.match(/^<!---([\w-]+)--->$/) || [])[1]
        if (match) {
            return match
        }
        fatalError(`Line contains comment marker but doesn't match marker pattern: ${line}`)
    }
}

export const fatalError = (message: string) => {
    console.log(message)
    process.exit(1)
}