from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
BA = ROOT / "BA_Documentation"

def load(relative):
    return json.loads((BA / relative).read_text())

def save(relative, data):
    (BA / relative).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

old_goal = "Thiết lập quan hệ thuê có hiệu lực giữa người thuê và phòng, ghi cọc ban đầu và cập nhật tình trạng phòng; hỗ trợ nguồn lịch xem đủ điều kiện."
new_goal = "Thiết lập quan hệ thuê có hiệu lực và cập nhật tình trạng phòng; tiền cọc thỏa thuận được lưu, cọc đã thu chỉ tự ghi khi lập trực tiếp với số tiền dương; hỗ trợ nguồn lịch xem đủ điều kiện."
extra_rule = " Nhánh lập từ lịch xem gọi createWithinTransaction với recordDeposit=false: lưu tiền cọc thỏa thuận nhưng không tự ghi COLLECTED. Nhánh lập trực tiếp mới tự ghi COLLECTED khi deposit dương."
catalog = load("02_Functional_Decomposition_Use_Case_Catalog/data/catalog.json")
case = next(item for item in catalog["useCases"] if item["id"] == "UC-TNT-05")
case["goal"] = new_goal
if extra_rule.strip() not in case["rule"]:
    case["rule"] += extra_rule
save("02_Functional_Decomposition_Use_Case_Catalog/data/catalog.json", catalog)
trace = load("02_Functional_Decomposition_Use_Case_Catalog/data/traceability.json")
traced = next(item for item in trace["useCases"] if item["id"] == "UC-TNT-05")
if extra_rule.strip() not in traced["rule"]:
    traced["rule"] += extra_rule
save("02_Functional_Decomposition_Use_Case_Catalog/data/traceability.json", trace)
for filename in ["05_Use_Case_Catalog.md", "07_Traceability_and_Coverage.md"]:
    target = BA / "02_Functional_Decomposition_Use_Case_Catalog" / filename
    text = target.read_text().replace(old_goal, new_goal)
    if filename == "07_Traceability_and_Coverage.md":
        start = text.index("## UC-TNT-05") if "## UC-TNT-05" in text else text.index("### UC-TNT-05")
        stop = text.find("\n##", start + 3)
        if stop < 0:
            stop = len(text)
        section = text[start:stop]
        if extra_rule.strip() not in section:
            section += "\n- Đính chính 29/10/2026: " + extra_rule.strip() + "\n"
            text = text[:start] + section + text[stop:]
    target.write_text(text)
analysis = load("06_Detailed_Use_Cases/data/behavioral-analysis.json")
note = next(item for item in analysis["useCases"] if item["id"] == "UC-TNT-05")
note["alternatives"] = ["B1: Chủ trọ lập từ lịch xem COMPLETED: kiểm tin/phòng/người xem active; tái dùng hoặc tạo Tenant đủ điều kiện; tạo lease với recordDeposit=false, lưu cọc thỏa thuận nhưng không ghi COLLECTED; đánh lịch LEASED, ẩn tin và hủy lịch đang chờ khác; kết thúc sau trả leaseId/tenantId."]
note["post"] = "Lease ACTIVE, phòng OCCUPIED; deposit lưu cọc thỏa thuận. Chỉ nhánh lập trực tiếp tự ghi COLLECTED khi deposit dương; nhánh từ lịch xem không tự ghi thu cọc."
if extra_rule.strip() not in note["rules"]:
    note["rules"].append(extra_rule.strip())
note = next(item for item in analysis["useCases"] if item["id"] == "UC-OPT-07.3")
added = "Tài sản phòng, lịch kiểm tra và phí dịch vụ không thuộc các điều kiện đếm chặn xóa; RoomAsset, RoomInspection, RoomServiceFee có onDelete: Cascade theo schema nguồn. Chưa chạy kiểm chứng cascade trên DB thật."
if added not in note["rules"]:
    note["rules"].append(added)
save("06_Detailed_Use_Cases/data/behavioral-analysis.json", analysis)
manifest = load("06_Detailed_Use_Cases/data/spec-manifest.json")
for record in manifest["useCases"]:
    if record["id"] not in ["UC-TNT-05", "UC-OPT-07.3", "UC-TNT-12.1", "UC-ADM-18.1"]:
        continue
    target = BA / "06_Detailed_Use_Cases" / record["file"]
    text = target.read_text()
    if record["id"] == "UC-TNT-05":
        text = text.replace(old_goal, new_goal)
        text = text.replace("Lease ACTIVE, phòng OCCUPIED và cọc ban đầu nếu dương.", "Lease ACTIVE, phòng OCCUPIED; cọc thỏa thuận được lưu. Chỉ nhánh trực tiếp tự ghi COLLECTED khi deposit dương; nhánh từ lịch xem không tự ghi thu cọc.")
        text = text.replace("tái dùng hoặc tạo Tenant đủ điều kiện, tạo lease;", "tái dùng hoặc tạo Tenant đủ điều kiện, tạo lease với recordDeposit=false: lưu cọc thỏa thuận nhưng không ghi COLLECTED;")
        lines = text.splitlines()
        for index, line in enumerate(lines):
            if line.startswith("| Quy tắc nghiệp vụ |") and "BR-04" not in line:
                lines[index] = line[:-2] + "<br>BR-04 — " + extra_rule.strip() + " [SVC, DTO] |"
        text = "\n".join(lines) + "\n"
    additions = {
        "UC-OPT-07.3": "Tài sản, lịch kiểm tra và phí dịch vụ không chặn xóa trong RoomsService.remove; các quan hệ RoomAsset, RoomInspection, RoomServiceFee khai báo onDelete: Cascade trong schema. Đây là ràng buộc nguồn, chưa kiểm chứng trên database triển khai.",
        "UC-TNT-12.1": "Chỉ có xem, thêm và gỡ người ở cùng; không có endpoint hoặc service sửa trực tiếp thông tin thành viên.",
        "UC-ADM-18.1": "Không có điều kiện bắt buộc reviewer khác Admin đã hỗ trợ submit. AdminVerificationService.review chỉ chặn before.landlordId === actor.userId; không được mô tả là cơ chế maker-checker cho Admin hỗ trợ nộp.",
    }
    if record["id"] in additions and additions[record["id"]] not in text:
        lines = text.splitlines()
        for index, line in enumerate(lines):
            if line.startswith("| Quy tắc nghiệp vụ |"):
                count = line.count("BR-") + 1
                lines[index] = line[:-2] + f"<br>BR-{count:02d} — " + additions[record["id"]] + " [SVC, DTO] |"
        text = "\n".join(lines) + "\n"
    target.write_text(text)
print("Corrected 4 UC scopes; preserved UC identifiers, actors, statuses and application code.")
