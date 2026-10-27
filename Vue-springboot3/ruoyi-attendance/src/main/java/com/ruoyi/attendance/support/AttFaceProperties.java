package com.ruoyi.attendance.support;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/** 密钥与SDK路径仅从部署配置读取。 */
@Component
@ConfigurationProperties(prefix="attendance.face")
public class AttFaceProperties {
    private boolean enabled;
    private String appId, sdkKey, sdkJar, nativeDir, encryptionKey;
    private double threshold=0.80;
    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean value) { enabled=value; }
    public String getAppId() { return appId; }
    public void setAppId(String value) { appId=value; }
    public String getSdkKey() { return sdkKey; }
    public void setSdkKey(String value) { sdkKey=value; }
    public String getSdkJar() { return sdkJar; }
    public void setSdkJar(String value) { sdkJar=value; }
    public String getNativeDir() { return nativeDir; }
    public void setNativeDir(String value) { nativeDir=value; }
    public String getEncryptionKey() { return encryptionKey; }
    public void setEncryptionKey(String value) { encryptionKey=value; }
    public double getThreshold() { return threshold; }
    public void setThreshold(double value) { threshold=value; }
}
