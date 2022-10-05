// THIS FILE IS MANAGED BY AN AUTOMATED WORKFLOW

module.exports = {
  overrides: [
    {
      files: ['*.yml', '*.yaml'],
      options: { singleQuote: false },
    },
    {
      files: ['Makefile'],
      options: { useTabs: true },
    },
  ],
  tabWidth: 2,
  useTabs: false,
  singleQuote: true,
  trailingComma: 'all',
  semi: true,
  printWidth: 100,
  htmlWhitespaceSensitivity: 'ignore',
};
