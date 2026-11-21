// ginkgo-live: runs Ginkgo's plan agent against the real Gemini API from the command line.
// Example: swift run --package-path Packages/GinkgoCore ginkgo-live plan --max-width 420
import Foundation

let exitCode = await LiveCommand.run(CommandLine.arguments)
exit(exitCode)
