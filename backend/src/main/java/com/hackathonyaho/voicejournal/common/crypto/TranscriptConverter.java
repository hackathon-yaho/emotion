package com.hackathonyaho.voicejournal.common.crypto;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;

/**
 * 발화 텍스트 암호화 (F5-02). <b>DB를 직접 조회해도 평문이 보이지 않는다.</b>
 *
 * <p><b>왜 변환기인가</b> — 엔티티 필드는 평문 {@code String}으로 남는다. 그래서
 * F7-07(관찰 근거 열람)·F9-05(대화 상세)가 코드 수정 없이 동작한다. 암호화를 서비스
 * 코드에 흩으면 <b>복호화를 빠뜨린 조회가 생기고, 그건 화면에 암호문이 뜨고 나서야
 * 발견된다.</b>
 *
 * <p><b>왜 pgcrypto가 아닌가</b> — DB에서 암호화하면 키가 SQL 쿼리에 실려 간다.
 * Supabase가 뚫리는 상황을 가정한 방어인데 키가 같은 통로로 지나가면 반쯤 무의미하다.
 *
 * <p><b>⚠️ 키를 잃으면 도그푸딩 발화 전체가 복호화 불가가 된다.</b> DB 백업과 같은
 * 급으로 다룬다 — 세 시크릿 중 이것만 저장소 밖 오프라인 사본을 둔다(phase-1 1-3-1).
 */
@Component
@Converter
public class TranscriptConverter implements AttributeConverter<String, String> {

    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int IV_BYTES = 12;
    private static final int TAG_BITS = 128;

    private final SecretKey key;
    private final SecureRandom random = new SecureRandom();

    public TranscriptConverter(@Value("${app.crypto.transcript-key}") String base64Key) {
        byte[] raw = Base64.getDecoder().decode(base64Key);
        if (raw.length != 16 && raw.length != 24 && raw.length != 32) {
            throw new IllegalStateException(
                    "TRANSCRIPT_ENC_KEY must decode to 16/24/32 bytes (got " + raw.length + ")");
        }
        this.key = new SecretKeySpec(raw, "AES");
    }

    /** 저장 형식은 {@code base64(iv || ciphertext+tag)} — IV를 같이 담아야 복호화할 수 있다. */
    @Override
    public String convertToDatabaseColumn(String plaintext) {
        if (plaintext == null) {
            return null;
        }
        try {
            byte[] iv = new byte[IV_BYTES];
            random.nextBytes(iv);

            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            byte[] encrypted = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            byte[] out = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, out, 0, iv.length);
            System.arraycopy(encrypted, 0, out, iv.length, encrypted.length);
            return Base64.getEncoder().encodeToString(out);

        } catch (Exception e) {
            // 예외 메시지에 평문이 실리지 않게 원인만 남긴다 (FR-092).
            throw new IllegalStateException("transcript encryption failed: " + e.getClass().getSimpleName());
        }
    }

    @Override
    public String convertToEntityAttribute(String stored) {
        if (stored == null) {
            return null;
        }
        try {
            byte[] all = Base64.getDecoder().decode(stored);
            byte[] iv = Arrays.copyOfRange(all, 0, IV_BYTES);
            byte[] encrypted = Arrays.copyOfRange(all, IV_BYTES, all.length);

            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);

        } catch (Exception e) {
            throw new IllegalStateException("transcript decryption failed: " + e.getClass().getSimpleName());
        }
    }
}
