# foxworth-uni Homebrew Tap

This is a Homebrew tap for foxworth-uni projects.

## Installation

You can install formulae from this tap directly:

```bash
brew install foxworth-uni/tap/<formula-name>
```

Or tap it first:

```bash
brew tap foxworth-uni/tap
brew install <formula-name>
```

## Available Formulae

- **[danny](Formula/danny.rb)** - Smart bundler analyzer for modern web applications

## Development

### Creating a New Formula

To create a new formula for a project:

```bash
brew create <url-to-release-tarball> --tap foxworth-uni/tap --set-name <formula-name>
```

### Testing a Formula

Test your formula locally before pushing:

```bash
brew install --build-from-source foxworth-uni/tap/<formula-name>
brew test foxworth-uni/tap/<formula-name>
```

### Updating a Formula

When a new version is released, update the formula:

1. Update the `url` and version in the formula file
2. Update the `sha256` hash:
   ```bash
   curl -L <new-url> | shasum -a 256
   ```
3. Commit and push the changes

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See individual formula files for license information.

