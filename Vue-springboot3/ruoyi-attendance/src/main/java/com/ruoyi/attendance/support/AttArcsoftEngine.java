package com.ruoyi.attendance.support;

import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;

/** 对实际虹软Java 3.0 SDK的运行时适配；专有JAR/DLL不进入仓库或构建产物。 */
@Component
public class AttArcsoftEngine {
    public static final String MODEL="ARCSOFT_3_0";
    private final AttFaceProperties properties;
    private URLClassLoader loader;
    private Object engine;
    private boolean initialized;
    public AttArcsoftEngine(AttFaceProperties properties) { this.properties=properties; }
    private Class<?> type(String name) throws ClassNotFoundException { return loader.loadClass("com.arcsoft.face."+name); }
    @SuppressWarnings({"rawtypes","unchecked"})
    private Object enumeration(String name,String value) throws ClassNotFoundException { return Enum.valueOf((Class)type("enums."+name),value); }
    private Object call(Object target,String method,Class<?>[] types,Object... args) throws ReflectiveOperationException {
        return target.getClass().getMethod(method,types).invoke(target,args);
    }
    private void ok(Object code,String action) {
        if (((Number)code).intValue()!=0) throw new ServiceException(action+"失败（虹软错误码"+code+"）");
    }
    public synchronized void requireReady() {
        if (!properties.isEnabled()) throw new ServiceException("人脸核验尚未启用");
        if (initialized) return;
        if (properties.getAppId()==null || properties.getAppId().isBlank() || properties.getSdkKey()==null || properties.getSdkKey().isBlank()) throw new ServiceException("请配置配套的虹软APP_ID与SDK_KEY");
        if (!Double.isFinite(properties.getThreshold()) || properties.getThreshold()<=0 || properties.getThreshold()>=1) throw new ServiceException("人脸比对阈值配置应在0与1之间");
        if (properties.getSdkJar()==null || properties.getNativeDir()==null) throw new ServiceException("请配置虹软JAR及本地库目录");
        try {
            Path jar=Path.of(properties.getSdkJar()).toAbsolutePath().normalize(), nativeDir=Path.of(properties.getNativeDir()).toAbsolutePath().normalize();
            if (!Files.isRegularFile(jar) || !Files.isDirectory(nativeDir)) throw new ServiceException("虹软SDK文件或本地库目录不存在");
            if (loader==null) loader=new URLClassLoader(new java.net.URL[]{jar.toUri().toURL()},getClass().getClassLoader());
            if (engine==null) engine=type("FaceEngine").getConstructor(String.class).newInstance(nativeDir.toString());
            int active=((Number)call(engine,"activeOnline",new Class[]{String.class,String.class},properties.getAppId(),properties.getSdkKey())).intValue();
            int already=((Number)call(enumeration("ErrorInfo","MERR_ASF_ALREADY_ACTIVATED"),"getValue",new Class[]{})).intValue();
            if (active!=0 && active!=already) throw new ServiceException("虹软激活失败（错误码"+active+"），请核对应用、平台、系统时间及网络");
            Object functions=type("FunctionConfiguration").getConstructor().newInstance();
            call(functions,"setSupportFaceDetect",new Class[]{Boolean.class},true);
            call(functions,"setSupportFaceRecognition",new Class[]{Boolean.class},true);
            Object config=type("EngineConfiguration").getConstructor().newInstance();
            call(config,"setDetectMode",new Class[]{type("enums.DetectMode")},enumeration("DetectMode","ASF_DETECT_MODE_IMAGE"));
            call(config,"setDetectFaceOrientPriority",new Class[]{type("enums.DetectOrient")},enumeration("DetectOrient","ASF_OP_ALL_OUT"));
            call(config,"setDetectFaceMaxNum",new Class[]{Integer.class},10);
            call(config,"setDetectFaceScaleVal",new Class[]{Integer.class},16);
            call(config,"setFunctionConfiguration",new Class[]{type("FunctionConfiguration")},functions);
            ok(call(engine,"init",new Class[]{type("EngineConfiguration")},config),"人脸引擎初始化");
            initialized=true;
        } catch (ServiceException e) { throw e; }
        catch (ReflectiveOperationException | java.io.IOException | LinkageError e) { throw new ServiceException("虹软SDK加载失败，请核对Java3.0包、x64本地库和运行依赖"); }
    }
    public synchronized byte[] extract(AttFaceImage image) {
        requireReady();
        try {
            List<Object> faces=new ArrayList<>();
            Class<?> format=type("enums.ImageFormat");
            Object bgr=enumeration("ImageFormat","CP_PAF_BGR24");
            ok(call(engine,"detectFaces",new Class[]{byte[].class,int.class,int.class,format,List.class},image.bytes(),image.width(),image.height(),bgr,faces),"人脸检测");
            if (faces.size()!=1) throw new ServiceException(faces.isEmpty()?"未检测到人脸，请正对镜头重新采集":"检测到多张人脸，请确保画面中只有本人");
            Object feature=type("FaceFeature").getConstructor().newInstance();
            ok(call(engine,"extractFaceFeature",new Class[]{byte[].class,int.class,int.class,format,type("FaceInfo"),type("FaceFeature")},image.bytes(),image.width(),image.height(),bgr,faces.get(0),feature),"人脸特征提取");
            return ((byte[])call(feature,"getFeatureData",new Class[]{})).clone();
        } catch (ReflectiveOperationException | LinkageError e) { throw new ServiceException("虹软特征提取接口异常，请检查SDK版本"); }
    }
    public synchronized double compare(byte[] enrolled,byte[] probe) {
        requireReady();
        try {
            Class<?> feature=type("FaceFeature");
            Object left=feature.getConstructor(byte[].class).newInstance((Object)enrolled);
            Object right=feature.getConstructor(byte[].class).newInstance((Object)probe);
            Object similar=type("FaceSimilar").getConstructor().newInstance();
            ok(call(engine,"compareFaceFeature",new Class[]{feature,feature,type("FaceSimilar")},left,right,similar),"人脸比对");
            double score=((Number)call(similar,"getScore",new Class[]{})).doubleValue();
            if (!Double.isFinite(score) || score<0 || score>1) throw new ServiceException("人脸比对结果异常");
            return score;
        } catch (ReflectiveOperationException | LinkageError e) { throw new ServiceException("虹软比对接口异常，请检查SDK版本"); }
    }
    @PreDestroy
    public synchronized void close() {
        try { if (initialized) call(engine,"unInit",new Class[]{}); } catch (Exception ignored) { }
        initialized=false;
        try { if (loader!=null) loader.close(); } catch (java.io.IOException ignored) { }
    }
}
