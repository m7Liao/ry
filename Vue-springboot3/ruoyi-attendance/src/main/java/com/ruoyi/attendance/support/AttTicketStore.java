package com.ruoyi.attendance.support;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import com.ruoyi.attendance.domain.AttCheckinSession;
import com.ruoyi.attendance.domain.vo.AttQrCodeView;
import com.ruoyi.attendance.domain.vo.AttQrTicket;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;

/** 随机二维码凭证只短期保存在 Redis，数据库不保存明文凭证。 */
@Component
public class AttTicketStore
{
    private static final SecureRandom RANDOM = new SecureRandom();
    private final RedisCache redisCache;
    private final int validSeconds;

    public AttTicketStore(RedisCache redisCache, @Value("${attendance.qr.valid-seconds:60}") int validSeconds)
    {
        if (validSeconds < 10 || validSeconds > 120) throw new IllegalArgumentException("二维码有效期应在10至120秒之间");
        this.redisCache = redisCache;
        this.validSeconds = validSeconds;
    }

    public AttQrCodeView issue(AttCheckinSession session)
    {
        long now = System.currentTimeMillis();
        long expiresAt = Math.min(now + validSeconds * 1000L, session.getEndTime().getTime());
        if (expiresAt <= now) throw new ServiceException("签到场次已结束");
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String ticket = HexFormat.of().formatHex(bytes);
        AttQrTicket value = new AttQrTicket();
        value.setSessionId(session.getSessionId());
        value.setExpiresAt(expiresAt);
        redisCache.setCacheObject(key(ticket), value, (int) Math.max(1, (expiresAt - now + 999) / 1000), TimeUnit.SECONDS);
        AttQrCodeView view = new AttQrCodeView();
        view.setTicket(ticket);
        view.setSessionId(session.getSessionId());
        view.setExpiresAt(expiresAt);
        view.setServerTime(now);
        view.setTitle(session.getTitle());
        view.setSiteName(session.getSiteName());
        return view;
    }

    public AttQrTicket resolve(String ticket)
    {
        AttQrTicket value = redisCache.getCacheObject(key(ticket));
        if (value == null || value.getExpiresAt() == null || value.getExpiresAt() <= System.currentTimeMillis())
        {
            throw new ServiceException("二维码已过期或无效，请重新扫描现场二维码");
        }
        return value;
    }

    private String key(String ticket)
    {
        try
        {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(ticket.getBytes(StandardCharsets.UTF_8));
            return "attendance:qr:ticket:" + HexFormat.of().formatHex(digest);
        }
        catch (NoSuchAlgorithmException e)
        {
            throw new IllegalStateException(e);
        }
    }
}
