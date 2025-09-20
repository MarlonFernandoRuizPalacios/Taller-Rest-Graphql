// Obtiene países por código y devuelve su continente
const countriesByCodesQuery = r'''
query Countries($codes: [ID!]) {
  countries(filter: { code: { in: $codes } }) {
    code
    name
    continent { name }
  }
}
''';
