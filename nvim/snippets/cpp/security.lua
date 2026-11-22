-- C++ snippets: security. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Crypto hygiene
	S("ctcmp", "[C++20] constant-time compare (prefer sodium_memcmp/CRYPTO_memcmp)", [=[
bool ${1:secure_equal}(std::span<const std::byte> a, std::span<const std::byte> b) noexcept {
    if (a.size() != b.size()) { return false; }
    unsigned char diff = 0;
    for (std::size_t i = 0; i < a.size(); ++i) {
        diff |= static_cast<unsigned char>(a[i] ^ b[i]);
    }
    return diff == 0;
}]=]),
	S("randbytes", "[Linux] cryptographic random bytes via getrandom", [=[
std::array<std::byte, ${1:32}> ${2:key};
if (getrandom($2.data(), $2.size(), 0) != static_cast<ssize_t>($2.size())) {
    ${0:throw std::system_error(errno, std::generic_category(), "getrandom");}
}]=]),
	S("evpctx", "[C++11] OpenSSL EVP_CIPHER_CTX owned by unique_ptr", [=[
using CipherCtx = std::unique_ptr<EVP_CIPHER_CTX, decltype(&EVP_CIPHER_CTX_free)>;
CipherCtx ${1:ctx}{EVP_CIPHER_CTX_new(), &EVP_CIPHER_CTX_free};
if (!$1) {
    ${0:throw std::runtime_error("EVP_CIPHER_CTX_new");}
}]=]),
}
