//
//  Icons.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/17/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

struct EdgeColor {
    static let border: Color = .secondary
    static let outline: Color = .secondary
}

struct EdgeWidth {
    static let border: CGFloat = 2
    static let outline: CGFloat = 1
}

//MARK: Table Icons

struct TableIcon: View {
    var rows: Int = 3
    var cols: Int = 3
    var inset: CGFloat = 3
    var selectRow: Int? = nil
    var selectCol: Int? = nil
    var withHeader: Bool = false
    var deleteRows: [Int]? = nil
    var deleteCols: [Int]? = nil
    var border: TableBorder = .none
    var body: some View {
        GeometryReader() { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let cellWidth = width / CGFloat(cols)
            let cellHeight = height / CGFloat(rows)
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { col in
                            let select = row == selectRow || col == selectCol
                            let delete = deleteRows?.contains(row) ?? false || deleteCols?.contains(col) ?? false
                            TableCell(
                                width: cellWidth,
                                height: cellHeight,
                                selected: select,
                                deleted: delete
                            )
                        }
                    }
                }
            }
            .frame(width: width, height: height)
            .overlay(
                TableIconBorder(width: width, height: height, rows: rows, cols: cols, withHeader: withHeader, border: border)
            )
        }
        .padding([.all], inset)
    }
}

struct TableCell: View {
    let width: CGFloat
    let height: CGFloat
    let selected: Bool
    let deleted: Bool
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: width, height: height)
                .foregroundColor(selected ? Color.accentColor.opacity(0.2) : Color (UIColor.systemBackground))
            if deleted {
                Image(systemName: "xmark")
                    .foregroundColor(Color.red)
                    .font(Font.system(size: min(width, height) - 2).weight(.bold))
            }
        }
    }
}

struct TableIconBorder: View {
    let width: CGFloat
    let height: CGFloat
    let rows: Int
    let cols: Int
    let withHeader: Bool
    let border: TableBorder
    var body: some View {
        let borderThickness = border == .none ? EdgeWidth.outline : EdgeWidth.border
        let borderColor = border == .none ? EdgeColor.outline : EdgeColor.border
        let cellWidth = width / CGFloat(cols)
        let cellHeight = height / CGFloat(rows)
        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(borderColor, lineWidth: borderThickness)
                .foregroundColor(Color.clear)
            ForEach(0..<rows, id:\.self) { row in
                let rowTopLineWidth = row == 0 ? borderThickness : rowLineWidth(for: row - 1)
                let rowBottomLineWidth = rowLineWidth(for: row)
                let rowBottomColor = rowColor(for: row)
                TableBorderRowSeparator(
                    row: row,
                    rows: rows,
                    rowWidth: width,
                    cellHeight: cellHeight,
                    color: rowBottomColor,
                    lineWidth: rowBottomLineWidth,
                    borderThickness: borderThickness)
                ForEach(0..<cols-1, id: \.self) { col in
                    let isHeader = withHeader ? row == 0 : false
                    let colTrailingColor = isHeader ? Color.clear : colColor(for: col)
                    let colTrailingLineWidth = colLineWidth(for: col)
                    TableBorderColSeparator(
                        row: row,
                        col: col,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        rowTopLineWidth: rowTopLineWidth,
                        rowBottomLineWidth: rowBottomLineWidth,
                        color: colTrailingColor,
                        lineWidth: colTrailingLineWidth)
                }
            }
        }
    }
    
    /// Return the color for the bottom edge of a row
    private func rowColor(for row: Int) -> Color {
        var color: Color
        switch border {
        case .outer, .none:
            color = EdgeColor.outline
        case .header:
            if row == 0 {
                color = EdgeColor.border
            } else {
                color = EdgeColor.outline
            }
        case .cell:
            color = EdgeColor.border
        }
        return color
    }
    
    /// Return the thickness for the bottom edge of a row
    private func rowLineWidth(for row: Int) -> CGFloat {
        var thickness: CGFloat
        switch border {
        case .outer, .none:
            thickness = EdgeWidth.outline
        case .header:
            if row == 0 {
                thickness = EdgeWidth.border
            } else {
                thickness = EdgeWidth.outline
            }
        case .cell:
            thickness = EdgeWidth.border
        }
        return thickness
    }
    
    /// Return the color for the trailing edge of a cell at col
    private func colColor(for col: Int) -> Color {
        var color: Color
        switch border {
        case .outer, .header, .none:
            color = EdgeColor.outline
        case .cell:
            color = EdgeColor.border
        }
        return color
    }

    /// Return the thickness for the trailing edge of a cell at col
    private func colLineWidth(for col: Int) -> CGFloat {
        var thickness: CGFloat
        switch border {
        case .outer, .header, .none:
            thickness = EdgeWidth.outline
        case .cell:
            thickness = EdgeWidth.border
        }
        return thickness
    }
}

struct TableBorderRowSeparator: View {
    let row: Int
    let rows: Int
    let rowWidth: CGFloat
    let cellHeight: CGFloat
    let color: Color
    let lineWidth: CGFloat
    let borderThickness: CGFloat
    var body: some View {
        let hideRowSeparator = row == rows - 1   // Don't draw line at bottom
        if !hideRowSeparator {
            let rowBottomOffset = cellHeight * CGFloat(row + 1)
            Path { path in
                path.move(to: CGPoint.zero)
                path.addLine(to: CGPoint(x: rowWidth - borderThickness, y: 0))
            }
            .offset(x: borderThickness / 2, y: rowBottomOffset)
            .stroke(color, lineWidth: lineWidth)
        } else {
            EmptyView()
        }
    }
}

struct TableBorderColSeparator: View {
    let row: Int
    let col: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let rowTopLineWidth: CGFloat
    let rowBottomLineWidth: CGFloat
    let color: Color
    let lineWidth: CGFloat
    var body: some View {
        let rowTopOffset = cellHeight * CGFloat(row)
        let colSeparatorHeight = cellHeight - (rowTopLineWidth + rowBottomLineWidth) / 2
        let colXOffset = cellWidth * CGFloat(col + 1)
        Path { path in
            path.move(to: CGPoint.zero)
            path.addLine(to: CGPoint(x: 0, y: colSeparatorHeight))
        }
        .offset(x: colXOffset, y: rowTopOffset + rowTopLineWidth / 2)
        .stroke(color, lineWidth: lineWidth)
    }
}

struct AddRow: View {
    let direction: TableDirection
    var body: some View {
        VStack(spacing: -6) {
            if direction == .after {
                ZStack(alignment: .bottom) {
                    TableIcon(rows: 3, cols: 3, selectRow: 2)
                    Image(systemName: "arrow.down")
                        .offset(CGSize(width: 0, height: -4))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                        .zIndex(1)
                }
            } else {
                ZStack(alignment: .top) {
                    Image(systemName: "arrow.up")
                        .offset(CGSize(width: 0, height: 4))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                        .zIndex(1)
                    TableIcon(rows: 3, cols: 3, selectRow: 0)
                }
            }
        }
    }
}

struct AddCol: View {
    let direction: TableDirection
    var body: some View {
        HStack(spacing: -6) {
            if direction == .after {
                ZStack(alignment: .trailing) {
                    TableIcon(rows: 3, cols: 3, selectCol: 2)
                    Image(systemName: "arrow.right")
                        .offset(CGSize(width: -4, height: 0))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                        .zIndex(1)
                }
            } else {
                ZStack(alignment: .leading) {
                    Image(systemName: "arrow.left")
                        .offset(CGSize(width: 4, height: 0))
                        .foregroundColor(Color.red)
                        .font(Font.system(size: 12).weight(.bold))
                            .zIndex(1)
                    TableIcon(rows: 3, cols: 3, selectCol: 0)
                }
            }
        }
    }
}

struct AddHeader: View {
    var body: some View {
        ZStack(alignment: .top) {
            TableIcon(rows: 3, cols: 3, selectRow: 0, withHeader: true)
            Image(systemName: "arrow.up")
                .offset(CGSize(width: 0, height: 4))
                .foregroundColor(Color.red)
                .font(Font.system(size: 12).weight(.bold))
                .zIndex(1)
        }
    }
}

struct DeleteRow: View {
    var body: some View {
        TableIcon(rows: 3, cols: 3, selectRow: 1, deleteRows: [1])
    }
}

struct DeleteCol: View {
    var body: some View {
        TableIcon(rows: 3, cols: 3, selectCol: 1, deleteCols: [1])
    }
}

struct DeleteTable: View {
    var body: some View {
        TableIcon(rows: 3, cols: 3, deleteRows: [0, 1, 2])
    }
}

struct CreateTable: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TableIcon(rows: 3, cols: 3, selectRow: 2, selectCol: 2)
            Image(systemName: "arrow.down.forward")
                .offset(CGSize(width: -4, height: -4))
                .foregroundColor(Color.red)
                .font(Font.system(size: 12).weight(.bold))
                .zIndex(1)
        }
    }
}

struct BorderIcon: View {
    var border: TableBorder = .none
    var body: some View {
        TableIcon(rows: 3, cols: 3, withHeader: true, border: border)
    }
    
    init(_ border: TableBorder) {
        self.border = border
    }
}

struct TableIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HStack(alignment: .top) {
                Group {
                    TableIcon()
                        .frame(width: 30, height: 30)
                    CreateTable()
                        .frame(width: 30, height: 30)
                }
                Divider()
                Group {
                    AddHeader()
                        .frame(width: 30, height: 30)
                    AddRow(direction: .after)
                        .frame(width: 30, height: 30)
                    AddRow(direction: .before)
                        .frame(width: 30, height: 30)
                    AddCol(direction: .after)
                        .frame(width: 30, height: 30)
                    AddCol(direction: .before)
                        .frame(width: 30, height: 30)
                }
                Divider()
                Group {
                    DeleteRow()
                        .frame(width: 30, height: 30)
                    DeleteCol()
                        .frame(width: 30, height: 30)
                    DeleteTable()
                        .frame(width: 30, height: 30)
                }
                Divider()
                Group {
                    BorderIcon(.cell)
                        .frame(width: 30, height: 30)
                    BorderIcon(.header)
                        .frame(width: 30, height: 30)
                    BorderIcon(.outer)
                        .frame(width: 30, height: 30)
                    BorderIcon(.none)
                        .frame(width: 30, height: 30)
                }
                Spacer()
            }
            .frame(height: 30)
            Spacer()
        }
    }
}
