-- 玩家扫码后的首屏故事简介，由管理端动态维护。
CREATE TABLE IF NOT EXISTS story_intro (
    id VARCHAR(32) PRIMARY KEY,
    title VARCHAR(80) NOT NULL,
    subtitle VARCHAR(160) NOT NULL,
    intro_text TEXT NOT NULL,
    warning_text TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

INSERT INTO story_intro (id, title, subtitle, intro_text, warning_text, updated_at) VALUES (
    'default',
    '纸嫁衣',
    '这一次，换你走进故事里',
    '奘铃村，一座被冥婚诅咒困住百年的村子。戏子梁少平宁死不肯送祝小红出嫁，横死在残坟之前；祝小红化为一缕阴魂，至今不散。从此每逢阴时，村中红烛亮起、纸人成行，静静等待 "新的新娘" 入殓。你将穿过红妆铜镜台、拜过喜堂怨偶、赴过阴间酒席 —— 十三重场景，步步惊心。记住：唯有祝小红，可平息残坟前煞金刚的怨恨；阴间之食，浆糊豆饼可安饥肠……当你踏进奘铃村那一刻起，故事，就已经开始了……',
    '本惊奇屋含惊吓与追逐，1.2 米以下儿童、老人、孕妇、心脏病患者请勿入内；感到不适可随时示意工作人员退出；场内禁止拍照录像。',
    CURRENT_TIMESTAMP
)
ON CONFLICT (id) DO NOTHING;
