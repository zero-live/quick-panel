//
//  ChangelogManager.swift
//  Quick Panel
//
//  Created by Codex on 2026/04/16.
//

import Foundation

struct ChangelogSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
}

struct ChangelogRelease: Identifiable {
    let id = UUID()
    let version: String
    let build: String?
    let status: String
    let sections: [ChangelogSection]
}

class ChangelogManager {
    static let shared = ChangelogManager()

    private init() {}

    let releases: [ChangelogRelease] = [
        ChangelogRelease(
            version: "1.4.0",
            build: "12",
            status: "当前版本",
            sections: [
                ChangelogSection(title: "新增", items: [
                    "新增原生液态玻璃与液态玻璃 · 清透主题，面板效果与 macOS Dock 的系统玻璃材质保持一致",
                    "面板透明度范围扩展至 20% - 100%，并提供实时预览"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复系统材质在非激活悬浮面板中退化为灰色模糊层的问题",
                    "修复调整透明度时图标和文字随背景一起变淡的问题"
                ]),
                ChangelogSection(title: "优化", items: [
                    "低透明度下使用自然的深灰内容与轻量中性灰承托，提升复杂壁纸上的可读性",
                    "优化玻璃圆角裁切与边界细节"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.3.0",
            build: "11",
            status: "已发布",
            sections: [
                ChangelogSection(title: "新增", items: [
                    "设置 - 外观 中新增多种系统毛玻璃材质选择，并提供实时预览"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复主面板深色模式下毛玻璃效果偏灰发闷的问题",
                    "修复面板翻页动画方向与实际翻页方向不一致的问题",
                    "修复删除含有内容的页面时缺少二次确认的问题"
                ]),
                ChangelogSection(title: "优化", items: [
                    "补充面板阴影与多项 hover、按压反馈",
                    "优化拖拽视觉反馈与误触判定",
                    "补充项目名称提示及应用、网站右键快捷操作"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.7",
            build: "10",
            status: "已发布",
            sections: [
                ChangelogSection(title: "修复", items: [
                    "修复已开启辅助功能权限后，应用仍显示未授权的问题",
                    "修复 Debug 构建重新签名后辅助功能授权失效的问题",
                    "修复打开辅助功能系统设置时 AppleScript 兜底报错的问题"
                ]),
                ChangelogSection(title: "优化", items: [
                    "优化 Debug 构建与 Xcode 运行前的签名稳定性，减少开发和重启后的重复授权",
                    "优化辅助功能权限引导文案，提示清理旧授权项后重新授权"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.6",
            build: "9",
            status: "已发布",
            sections: [
                ChangelogSection(title: "修复", items: [
                    "修复主面板项目右键菜单失效的问题，恢复编辑与删除入口",
                    "修复下层面板滚轮翻页时，面板内容或窗口发生上下偏移的问题"
                ]),
                ChangelogSection(title: "优化", items: [
                    "优化滚轮事件处理，面板内滚轮只用于翻页，不再继续传递给内部视图",
                    "优化下层页码记忆保存逻辑，避免页码变更触发全局设置重排"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.5",
            build: "8",
            status: "已发布",
            sections: [
                ChangelogSection(title: "优化", items: [
                    "优化辅助功能权限引导策略，避免未授权时每次启动都弹出系统权限提示",
                    "自动权限引导增加 24 小时冷却，减少开发和日常使用中的重复打扰"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复辅助功能未授权时，每次运行都会重复弹出权限提示的问题"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.4",
            build: "7",
            status: "已发布",
            sections: [
                ChangelogSection(title: "新增", items: [
                    "新增主面板项目跨页移动能力，可将应用或网站从当前页移动到其他页",
                    "新增基于页面与槽位的项目位置模型，提升分页布局的稳定性"
                ]),
                ChangelogSection(title: "优化", items: [
                    "优化主面板拖拽换位交互，支持项目移动到已占用格子时后续项目顺延",
                    "优化跨页拖动边缘提示，拖动到左右边缘时显示可切页区域",
                    "优化拖动过程中的空格子 hover 状态，避免误显示添加高亮"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复项目只能在当前页调整、无法跨页移动的问题",
                    "修复快速拖动和跨页拖动后项目偶发无法继续移动的问题"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.3",
            build: "6",
            status: "已发布",
            sections: [
                ChangelogSection(title: "优化", items: [
                    "优化添加项目窗口的类型选择顺序，将网站放在应用程序前面",
                    "优化添加项目窗口默认类型，默认选中网站，贴合更高频的网站添加场景"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复下层面板第二页添加网站后项目会被保存到第一页的问题"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.2",
            build: "5",
            status: "已发布",
            sections: [
                ChangelogSection(title: "优化", items: [
                    "优化主面板上下层布局，整体更紧凑，减少无效留白",
                    "优化下层分页状态记忆，按应用维度恢复最近访问页面",
                    "优化主面板滚轮翻页命中逻辑，避免滚动事件串到内容区域"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复滚轮切换页面时面板内容跟随垂直滚动的问题",
                    "修复滚轮切换页码时命中标题区域会误切换上层页面的问题",
                    "修复主面板顶部和底部内容偶发显示不全的问题",
                    "修复 Xcode 重新运行后全局快捷键偶发失效的问题"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.1",
            build: "4",
            status: "已发布",
            sections: [
                ChangelogSection(title: "新增", items: [
                    "新增统一日志基础设施，并接入关键链路日志",
                    "新增导出最近 24 小时日志能力",
                    "新增打开日志目录入口",
                    "新增本地日志按天分文件、保留最近 7 天的策略",
                    "新增清空本地日志能力"
                ]),
                ChangelogSection(title: "优化", items: [
                    "优化网站图标与网站标题自动获取",
                    "优化添加项目窗口布局与绑定应用展示",
                    "优化主界面标题栏、空状态提示与分组标题编辑交互",
                    "优化管理页筛选、批量操作和交互细节",
                    "优化设置页与管理页交互体验"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复下层添加项目时前台应用识别不稳定的问题",
                    "修复下层项目首次打开面板显示为空白的问题",
                    "修复管理页中网站项目副标题未正确显示网址的问题",
                    "修复调试日志导出在沙盒环境下失败的问题",
                    "修复保存面板所需的文件读写权限配置"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.2.0",
            build: "3",
            status: "已发布",
            sections: [
                ChangelogSection(title: "新增", items: [
                    "新增应用内自动检查更新能力",
                    "新增 DMG 安装包流程",
                    "新增全局快捷键呼出面板能力",
                    "新增分页、新建页面、删除页面与分页指示",
                    "新增页面分组标题编辑能力"
                ]),
                ChangelogSection(title: "优化", items: [
                    "调整项目结构，整理发布产物目录",
                    "优化多实例检测与应用启动流程",
                    "优化首次弹窗位置与前台应用识别时机"
                ]),
                ChangelogSection(title: "修复", items: [
                    "修复快捷键触发后面板未正确显示的问题",
                    "修复添加项目时新项目落入第一页的问题",
                    "修复分页系统核心 bug 与滚轮跳页问题",
                    "修复删除页面失败的问题"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.0.1",
            build: nil,
            status: "已发布",
            sections: [
                ChangelogSection(title: "优化", items: [
                    "继续稳定首个正式版本后的基础体验",
                    "调整细节并补充发布修正"
                ])
            ]
        ),
        ChangelogRelease(
            version: "1.0.0",
            build: nil,
            status: "首个正式版本",
            sections: [
                ChangelogSection(title: "首次发布", items: [
                    "提供鼠标中键呼出快捷面板能力",
                    "支持上层常用项目与下层按前台应用分组的项目",
                    "支持启动应用、打开网站、拖拽排序、分页与基础设置"
                ])
            ]
        )
    ]
}
