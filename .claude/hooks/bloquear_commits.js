// Hook PreToolUse (Bash): bloquea cualquier `git commit` lanzado por el agente.
let entrada = ''
process.stdin.on('data', (trozo) => (entrada += trozo))
process.stdin.on('end', () => {
  let comando = ''
  try {
    comando = JSON.parse(entrada).tool_input?.command ?? ''
  } catch {
    process.exit(0)
  }
  // `git commit`, también con opciones intermedias (git -C dir commit) o en cadenas (a && git commit)
  const es_commit = /(^|[;&|(\n]\s*)git(\s+(-[Cc]\s+\S+|--?[\w-]+(=\S+)?))*\s+commit\b/.test(comando)
  if (!es_commit) process.exit(0)
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason:
          'Los commits los hace el usuario manualmente: el agente no puede ejecutar git commit.',
      },
    }),
  )
})
