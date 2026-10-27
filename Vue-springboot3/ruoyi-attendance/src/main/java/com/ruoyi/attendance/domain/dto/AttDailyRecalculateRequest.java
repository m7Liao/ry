package com.ruoyi.attendance.domain.dto;

import java.util.List;
import jakarta.validation.constraints.*;

public class AttDailyRecalculateRequest
{
    @NotEmpty(message = "请选择需要重新计算的结果") @Size(max = 100, message = "每次最多重算100条")
    private List<@NotNull @Positive Long> resultIds;
    public List<Long> getResultIds() { return resultIds; }
    public void setResultIds(List<Long> resultIds) { this.resultIds = resultIds; }
}
