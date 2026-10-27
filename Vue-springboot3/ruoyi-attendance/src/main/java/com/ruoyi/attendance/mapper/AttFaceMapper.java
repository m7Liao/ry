package com.ruoyi.attendance.mapper;
import java.util.Map;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.AttFaceProfile;
public interface AttFaceMapper {
    AttFaceProfile selectProfile(Long employeeId);
    int saveProfile(AttFaceProfile profile);
    int deleteProfile(Long employeeId);
    int insertVerification(@Param("recordId") Long recordId,@Param("score") double score,@Param("threshold") double threshold,@Param("version") long version,@Param("model") String model);
    Map<String,Object> selectVerification(Long recordId);
}
