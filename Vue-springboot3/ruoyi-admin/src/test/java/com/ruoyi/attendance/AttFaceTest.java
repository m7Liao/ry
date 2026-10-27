package com.ruoyi.attendance;

import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.*;
import java.security.SecureRandom;
import java.util.*;
import javax.imageio.ImageIO;
import org.springframework.web.multipart.MultipartFile;
import org.yaml.snakeyaml.Yaml;
import com.ruoyi.attendance.support.*;
import com.ruoyi.common.exception.ServiceException;

/** 无模拟识别引擎：普通模式检查加密/图片边界，native模式直接运行本机虹软SDK。 */
public class AttFaceTest {
    public static class Upload implements MultipartFile {
        private final byte[] data;
        public Upload(byte[] data) { this.data=data; }
        public String getName() { return "image"; }
        public String getOriginalFilename() { return "face.png"; }
        public String getContentType() { return "image/png"; }
        public boolean isEmpty() { return data.length==0; }
        public long getSize() { return data.length; }
        public byte[] getBytes() { return data; }
        public InputStream getInputStream() { return new ByteArrayInputStream(data); }
        public void transferTo(File dest) throws IOException { Files.write(dest.toPath(),data); }
    }
    private static void check(boolean ok,String message) { if (!ok) throw new AssertionError(message); }
    private static void denied(Runnable action,String label) {
        try { action.run(); } catch (ServiceException e) { return; }
        throw new AssertionError(label);
    }
    private static byte[] png(int width,int height) throws IOException {
        var image=new BufferedImage(width,height,BufferedImage.TYPE_INT_RGB);
        var out=new ByteArrayOutputStream(); ImageIO.write(image,"PNG",out); return out.toByteArray();
    }
    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        var properties=new AttFaceProperties(); byte[] key=new byte[32]; new SecureRandom().nextBytes(key);
        properties.setEncryptionKey(Base64.getEncoder().encodeToString(key));
        var cipher=new AttFaceCipher(properties); byte[] feature=new byte[1032]; new SecureRandom().nextBytes(feature);
        byte[] a=cipher.encrypt(1,feature), b=cipher.encrypt(1,feature);
        check(!Arrays.equals(a,b),"GCM nonce reused"); check(Arrays.equals(feature,cipher.decrypt(1,a)),"Feature roundtrip failed");
        denied(()->cipher.decrypt(2,a),"Feature accepted under another employee");
        a[a.length-1]^=1; denied(()->cipher.decrypt(1,a),"Tampered feature accepted");
        properties.setEncryptionKey("bad"); denied(cipher::validate,"Invalid encryption key accepted");
        denied(()->AttFaceImage.read(new Upload(new byte[0])),"Empty image accepted");
        denied(()->AttFaceImage.read(new Upload(new byte[]{1,2,3})),"Invalid image bytes accepted");
        denied(()->AttFaceImage.read(new Upload(new byte[4*1024*1024+1])),"Oversized image accepted");
        byte[] tiny=png(16,16); denied(()->AttFaceImage.read(new Upload(tiny)),"Too-small image accepted");
        var image=AttFaceImage.read(new Upload(png(101,90)));
        check(image.width()%4==0 && image.bytes().length==image.width()*image.height()*3,"BGR24 layout wrong");
        System.out.println("PASS: authenticated feature encryption and image decode/size/BGR boundaries");
        if (args.length>0 && args[0].equals("native")) {
            Map<String,Object> root=new Yaml().load(Files.readString(Path.of("../.runtime/arcsoft/face-local.yml")));
            Map<String,Object> config=(Map<String,Object>)((Map<String,Object>)root.get("attendance")).get("face");
            properties.setEnabled(true); properties.setAppId((String)config.get("app-id")); properties.setSdkKey((String)config.get("sdk-key"));
            properties.setSdkJar((String)config.get("sdk-jar")); properties.setNativeDir((String)config.get("native-dir"));
            properties.setThreshold(((Number)config.get("threshold")).doubleValue());
            var engine=new AttArcsoftEngine(properties);
            try {
                engine.requireReady();
                System.out.println("PASS: real ArcSoft Java 3.0 x64 engine activated and initialized on Java 17");
                denied(()->engine.extract(image),"Blank image incorrectly accepted as face");
                System.out.println("PASS: real engine rejects image with no face");
                if (args.length>1) {
                    var portrait=AttFaceImage.read(new Upload(Files.readAllBytes(Path.of(args[1]))));
                    byte[] actual=engine.extract(portrait);
                    double score=engine.compare(actual,actual);
                    check(score>=properties.getThreshold(),"Real same-feature comparison below threshold");
                    System.out.println("PASS: real portrait feature extraction and same-face comparison, score="+score);
                    if (args.length>2) {
                        byte[] different=engine.extract(AttFaceImage.read(new Upload(Files.readAllBytes(Path.of(args[2])))));
                        double mismatch=engine.compare(actual,different);
                        check(mismatch<properties.getThreshold(),"Different-person fixture unexpectedly matched");
                        System.out.println("PASS: real different-face comparison rejected, score="+mismatch);
                    }
                    if (args.length>3) {
                        var multiple=AttFaceImage.read(new Upload(Files.readAllBytes(Path.of(args[3]))));
                        denied(()->engine.extract(multiple),"Multiple-face image accepted");
                        System.out.println("PASS: real engine rejects multiple-face fixture");
                    }
                }
            } finally { engine.close(); }
        }
    }
}
