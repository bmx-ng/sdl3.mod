#include <stdint.h>
/* Change the second test link's serial and regenerate Ogg CRCs without an encoder. */
void test_vorbis_reserialise(unsigned char *data, int length) {
	int pos = 0;
	while (pos + 27 <= length) {
		unsigned char *page = data + pos;
		int bytes = 27 + page[26];
		if (pos + bytes > length) return;
		for (int i = 0; i < page[26]; ++i) bytes += page[27 + i];
		if (pos + bytes > length) return;
		page[14] ^= 0x55;
		for (int i = 22; i < 26; ++i) page[i] = 0;
		uint32_t crc = 0;
		for (int i = 0; i < bytes; ++i) {
			crc ^= (uint32_t)page[i] << 24;
			for (int bit = 0; bit < 8; ++bit)
				crc = (crc << 1) ^ ((crc & 0x80000000U) ? 0x04c11db7U : 0);
		}
		for (int i = 0; i < 4; ++i) page[22 + i] = (unsigned char)(crc >> (i * 8));
		pos += bytes;
	}
}
