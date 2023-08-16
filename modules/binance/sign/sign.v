module sign

import crypto.hmac
import crypto.sha256

pub fn sign(secret_key string, msg string) string {
	return hmac.new(secret_key.bytes(), msg.bytes(), sha256.sum256, sha256.block_size).hex()
}
