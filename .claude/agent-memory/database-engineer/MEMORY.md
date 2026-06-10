# Database Engineer Memory Index

- [用户管理模块 migration 设计决策](project_user_module.md) — users/admin_users 表已完成，users 悬空外键已在 20260610120001 补全
- [活动与二维码模块 migration 设计决策](project_activities_qrcodes_module.md) — activities/qr_codes/qr_scan_events 表已完成，users 外键已补全
- [资料管理模块 migration 设计决策](project_materials_module.md) — materials/material_claims 表已完成，activity_id FK 待 20260610120001 执行后补全
- [线索管理模块 migration 设计决策](project_leads_module.md) — leads/follow_up_records/appointments 表已完成；risk_level_enum 定义于 migration 4，leads.risk_level 暂用 text+CHECK，待升级
- [测评报告模块 migration 设计决策](project_assessment_module.md) — assessment_questions/assessment_reports/report_raw_answers 表已完成，risk_level_enum 在 20260610120004 首次定义
- [问答记录与知识库模块 migration 设计决策](project_qa_knowledge_module.md) — knowledge_items/qa_records/qa_record_knowledge_refs 表已完成，lead_id FK 待 20260610120003 执行后补全
