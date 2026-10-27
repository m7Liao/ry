package com.ruoyi.attendance.support;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;
/** 每份特征使用独立随机nonce，员工ID作为AAD，禁止跨员工替换密文。 */
@Component
public class AttFaceCipher {
    private final AttFaceProperties properties;
    private final SecureRandom random=new SecureRandom();
    public AttFaceCipher(AttFaceProperties properties) { this.properties=properties; }
    private SecretKeySpec key() {
        try {
            byte[] bytes=Base64.getDecoder().decode(properties.getEncryptionKey());
            if (bytes.length!=32) throw new IllegalArgumentException();
            return new SecretKeySpec(bytes,"AES");
        } catch (IllegalArgumentException | NullPointerException e) { throw new ServiceException("人脸特征加密密钥需配置为32字节Base64，请联系管理员"); }
    }
    public void validate() { key(); }
    public byte[] encrypt(long employeeId,byte[] feature) {
        byte[] nonce=new byte[12]; random.nextBytes(nonce);
        byte[] encrypted=crypt(Cipher.ENCRYPT_MODE,employeeId,nonce,feature);
        return ByteBuffer.allocate(12+encrypted.length).put(nonce).put(encrypted).array();
    }
    public byte[] decrypt(long employeeId,byte[] encrypted) {
        if (encrypted==null || encrypted.length<29) throw new ServiceException("人脸档案数据无效，请重新采集");
        ByteBuffer buffer=ByteBuffer.wrap(encrypted); byte[] nonce=new byte[12]; buffer.get(nonce);
        byte[] payload=new byte[buffer.remaining()]; buffer.get(payload);
        return crypt(Cipher.DECRYPT_MODE,employeeId,nonce,payload);
    }
    private byte[] crypt(int mode,long employeeId,byte[] nonce,byte[] payload) {
        var secret=key();
        try {
            Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(mode,secret,new GCMParameterSpec(128,nonce));
            cipher.updateAAD(Long.toString(employeeId).getBytes(StandardCharsets.UTF_8));
            return cipher.doFinal(payload);
        } catch (java.security.GeneralSecurityException e) { throw new ServiceException("人脸特征加解密失败，请核对本机密钥与数据库备份"); }
    }
}
