import XCTest
@testable import PocketCore

final class StatementImportTests: XCTestCase {
    private func day(_ s: String) -> Day { Day(iso: s)! }
    private let today = Day(iso: "2026-11-26")!

    func testReadsQuotedFieldsAndOtherSeparators() {
        let rows = CSVReader.rows("\u{FEFF}Date,Description,Amount\r\n2026-11-20,\"Shop, \"\"The\"\" Best\",-12.50\r\n\r\n")
        XCTAssertEqual(rows, [["Date", "Description", "Amount"], ["2026-11-20", "Shop, \"The\" Best", "-12.50"]])
        XCTAssertEqual(CSVReader.rows("Datum;Betrag\n20.11.2026;-1.234,56\n"), [["Datum", "Betrag"], ["20.11.2026", "-1.234,56"]])
        XCTAssertEqual(CSVReader.rows("a\tb\n1\t2"), [["a", "b"], ["1", "2"]])
        XCTAssertEqual(CSVReader.rows("Memo,Amount\n\"two\nlines\",5"), [["Memo", "Amount"], ["two\nlines", "5"]])
    }

    func testReadsAmountsTheWayBanksWriteThem() {
        XCTAssertEqual(StatementImport.parseAmount("-12.34"), -1_234)
        XCTAssertEqual(StatementImport.parseAmount("(12.34)"), -1_234)
        XCTAssertEqual(StatementImport.parseAmount("12.34-"), -1_234)
        XCTAssertEqual(StatementImport.parseAmount("$1,234.56"), 123_456)
        XCTAssertEqual(StatementImport.parseAmount("-$1,234.56"), -123_456)
        XCTAssertEqual(StatementImport.parseAmount("1.234,56 €"), 123_456)
        XCTAssertEqual(StatementImport.parseAmount("12.34 DR"), -1_234)
        XCTAssertEqual(StatementImport.parseAmount("12.34 CR"), 1_234)
        XCTAssertEqual(StatementImport.parseAmount("USD 7"), 700)
        XCTAssertNil(StatementImport.parseAmount(""))
        XCTAssertNil(StatementImport.parseAmount("pending"))
    }

    func testReadsDatesTheWayBanksWriteThem() {
        XCTAssertEqual(StatementImport.parseDate("2026-11-20", dayFirst: false), day("2026-11-20"))
        XCTAssertEqual(StatementImport.parseDate("11/20/2026", dayFirst: false), day("2026-11-20"))
        XCTAssertEqual(StatementImport.parseDate("20/11/26", dayFirst: true), day("2026-11-20"))
        XCTAssertEqual(StatementImport.parseDate("20.11.2026", dayFirst: true), day("2026-11-20"))
        XCTAssertEqual(StatementImport.parseDate("Nov 20, 2026", dayFirst: false), day("2026-11-20"))
        XCTAssertEqual(StatementImport.parseDate("20 Nov 2026", dayFirst: false), day("2026-11-20"))
        XCTAssertEqual(StatementImport.parseDate("20-Nov-26", dayFirst: false), day("2026-11-20"))
        XCTAssertEqual(StatementImport.parseDate("2026-11-20 14:03:00", dayFirst: false), day("2026-11-20"))
        XCTAssertNil(StatementImport.parseDate("13/20/2026", dayFirst: false))
    }

    /// A week someone forgot to log: two purchases they did record by hand are flagged, the rest are new.
    func testPreviewFlagsWhatIsAlreadyRecorded() throws {
        var ledger = Ledger(entries: [Entry(cents: 50_000, label: "Starting balance", day: day("2026-11-01"), category: Categories.start)])
        ledger.add(Entry(cents: -450, label: "Coffee", day: day("2026-11-19"), category: "food"))
        ledger.add(Entry(cents: -6_000, label: "Groceries", day: day("2026-11-21"), category: "food"))
        let csv = """
        Transaction Date,Post Date,Description,Category,Type,Amount,Memo
        11/20/2026,11/21/2026,STARBUCKS #1234,Food & Drink,Sale,-4.50,
        11/21/2026,11/22/2026,WHOLE FOODS,Groceries,Sale,-60.00,
        11/22/2026,11/22/2026,Coffee shop,Food & Drink,Sale,-4.50,
        11/22/2026,11/22/2026,Coffee shop,Food & Drink,Sale,-4.50,
        11/23/2026,11/23/2026,PAYROLL,,,"1,500.00",
        11/24/2026,11/24/2026,Pending,,,,
        Total,,,,,"1,427.00",
        """
        let preview = try StatementImport.preview(csv, ledger: ledger, today: today)
        XCTAssertEqual(preview.columns, StatementColumns(headerRow: 0, date: 0, description: 2, amount: 5))
        XCTAssertEqual(preview.rows.map(\.label), ["STARBUCKS #1234", "WHOLE FOODS", "Coffee shop", "Coffee shop", "PAYROLL"])
        XCTAssertEqual(preview.rows.map(\.cents), [-450, -6_000, -450, -450, 150_000])
        guard case .recorded(let coffee) = preview.rows[0].duplicate else { return XCTFail("The hand-logged coffee") }
        XCTAssertEqual(coffee.label, "Coffee")
        guard case .recorded(let groceries) = preview.rows[1].duplicate else { return XCTFail("The hand-logged groceries") }
        XCTAssertEqual(groceries.label, "Groceries")
        XCTAssertNil(preview.rows[2].duplicate, "Each recorded entry explains one row")
        XCTAssertEqual(preview.rows[3].duplicate, .repeated(line: 4))
        XCTAssertTrue(preview.rows[3].includedByDefault, "Two identical coffees can both be real")
        XCTAssertFalse(preview.rows[0].includedByDefault)
        XCTAssertEqual(preview.skipped.map(\.line), [7, 8])
        XCTAssertEqual(preview.duplicates, 3)
        XCTAssertFalse(preview.ambiguousDates, "20 can only be a day")
        XCTAssertEqual(preview.rows[2].category, "food", "Guessed from a recorded entry with a similar name")
    }

    func testDebitAndCreditColumnsAndFlippedSigns() throws {
        let csv = """
        Account statement for checking
        Exported 2026-11-26

        Date,Details,Withdrawals,Deposits,Balance
        03/11/2026,Rent,800.00,,1200.00
        05/11/2026,Salary,,2000.00,3200.00
        """
        let preview = try StatementImport.preview(csv, ledger: Ledger(), today: today, localeDayFirst: true)
        XCTAssertEqual(preview.columns, StatementColumns(headerRow: 2, date: 0, description: 1, debit: 2, credit: 3))
        XCTAssertEqual(preview.rows.map(\.cents), [-80_000, 200_000])
        XCTAssertTrue(preview.ambiguousDates, "3/11 and 5/11 read both ways")
        XCTAssertEqual(preview.rows.first?.day, day("2026-11-03"), "Falls back to how the Mac writes dates")
        let monthFirst = try StatementImport.preview(csv, ledger: Ledger(), today: today, dayFirst: false)
        XCTAssertEqual(monthFirst.rows.first?.day, day("2026-03-11"))

        let card = "Date,Description,Amount\n2026-11-20,Bookshop,25.00\n2026-11-21,Refund,-5.00\n"
        let flipped = try StatementImport.preview(card, ledger: Ledger(), today: today, flipSigns: true)
        XCTAssertEqual(flipped.rows.map(\.cents), [-2_500, 500])
    }

    func testReadsAFileWithoutAHeader() throws {
        let preview = try StatementImport.preview("2026-11-20,Bakery,-3.20\n2026-11-21,Bus,-2.00\n", ledger: Ledger(), today: today)
        XCTAssertEqual(preview.columns, StatementColumns(headerRow: nil, date: 0, description: 1, amount: 2))
        XCTAssertEqual(preview.rows.count, 2)
    }

    func testRejectsFilesItCannotRead() {
        XCTAssertThrowsError(try StatementImport.preview("", ledger: Ledger(), today: today))
        XCTAssertThrowsError(try StatementImport.preview("Name,Notes\nSam,hello\n", ledger: Ledger(), today: today))
    }
}
