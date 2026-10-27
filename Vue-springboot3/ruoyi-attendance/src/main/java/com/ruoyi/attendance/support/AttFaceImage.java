package com.ruoyi.attendance.support;

import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.exception.ServiceException;

/** 限制压缩大小与解码像素，统一为SDK的BGR24格式；原图不落盘。 */
public record AttFaceImage(byte[] bytes, int width, int height) {
    public static AttFaceImage read(MultipartFile file) {
        if (file == null || file.isEmpty() || file.getSize()>4*1024*1024) throw new ServiceException("请提供不超过4MB的JPEG或PNG人脸图片");
        try (ImageInputStream stream=ImageIO.createImageInputStream(new ByteArrayInputStream(file.getBytes()))) {
            var readers=ImageIO.getImageReaders(stream);
            if (!readers.hasNext()) throw new ServiceException("图片内容无法识别，仅支持JPEG和PNG");
            ImageReader reader=readers.next();
            try {
                reader.setInput(stream);
                String format=reader.getFormatName();
                if (!format.equalsIgnoreCase("JPEG") && !format.equalsIgnoreCase("PNG")) throw new ServiceException("仅支持JPEG和PNG图片");
                int w=reader.getWidth(0), h=reader.getHeight(0);
                if (w<80 || h<80 || w>4096 || h>4096 || (long)w*h>8_000_000) throw new ServiceException("图片尺寸需至少80×80且不超过4096边长和800万像素");
                double scale=Math.min(1d,1280d/Math.max(w,h));
                int width=Math.max(4,(int)(w*scale)/4*4), height=Math.max(1,(int)(h*scale));
                BufferedImage source=reader.read(0), image=new BufferedImage(width,height,BufferedImage.TYPE_3BYTE_BGR);
                Graphics2D graphics=image.createGraphics();
                try { graphics.drawImage(source,0,0,width,height,null); } finally { graphics.dispose(); }
                return new AttFaceImage(((DataBufferByte)image.getRaster().getDataBuffer()).getData(),width,height);
            } finally { reader.dispose(); }
        } catch (IOException | IllegalArgumentException e) { throw new ServiceException("图片读取失败，请重新采集"); }
    }
}
