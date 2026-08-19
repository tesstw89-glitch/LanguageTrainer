import SwiftUI

enum AppRoute: Hashable {
    case exerciseHome(AppLanguage)

    case match(AppLanguage, week: Int)
    case dragAndFill(AppLanguage, week: Int)
    case dragAndFillCorrelation(AppLanguage, phrase: String)
    case speak(AppLanguage, week: Int)
    case listenMatch(AppLanguage, week: Int)
    case write(AppLanguage, week: Int)
    case matchWrite(AppLanguage, week: Int)
    case fullStudyFlow(AppLanguage, week: Int)
    case listenWrite(AppLanguage, week: Int)
    case listenWriteCorrelation(AppLanguage, phrase: String)

    // ✅ LESSONS
    case lessonsHome(AppLanguage)
    case lessonUnit(AppLanguage, unit: Int)
    case lessonFlow(AppLanguage, unit: Int, lesson: Int)

    case weeks(AppLanguage)
    case chooseWeek(AppLanguage)
    case startNewWeek(AppLanguage)
}
