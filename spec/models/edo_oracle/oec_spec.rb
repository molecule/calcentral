describe EdoOracle::Oec do
  let(:term_code) { '2016-D' }
  let(:term_id) { '2168' }

  let(:depts_clause) { EdoOracle::Oec.depts_clause(term_code, course_codes) }

  context 'department-specific queries' do
    subject { depts_clause }

    context 'complex exceptions' do
      let(:fake_dept_code) {'FAKECODE'}
      let(:fake_dept_name) {'FAKEDEPT'}
      let(:id_in_other_dept) {'66OT'}
      let(:explicitly_excluded_id) {'86EX'}
      let(:explicitly_included_id) {'42IN'}
      # The EdoOracle::Oec.depts_clause method currently queries Junction's Oec::CourseCode table, as well
      # as accepting an input list of CourseCode records. We therefore need to load some test data.
      before do
        Oec::CourseCode.create(dept_name: fake_dept_name, catalog_id: '', dept_code: fake_dept_code, include_in_oec: true)
        Oec::CourseCode.create(dept_name: fake_dept_name, catalog_id: id_in_other_dept, dept_code: 'LPSPP', include_in_oec: true)
        Oec::CourseCode.create(dept_name: fake_dept_name, catalog_id: explicitly_excluded_id, dept_code: fake_dept_code, include_in_oec: false)
        Oec::CourseCode.create(dept_name: fake_dept_name, catalog_id: explicitly_included_id, dept_code: fake_dept_code, include_in_oec: true)
      end
      let(:course_codes) do
        [
          Oec::CourseCode.new(dept_name: fake_dept_name, catalog_id: '', dept_code: fake_dept_code, include_in_oec: true)
        ]
      end
      it { should include(
        "sec.\"displayName\" LIKE '#{fake_dept_name} %'",
        "sec.\"displayName\" != '#{fake_dept_name} #{id_in_other_dept}'",
        "sec.\"displayName\" != '#{fake_dept_name} #{explicitly_excluded_id}'"
      ) }
      it { should_not include "sec.\"displayName\" != '#{fake_dept_name} #{explicitly_included_id}'" }
    end

    context 'limiting query by department code' do
      let(:course_codes) do
        [
          Oec::CourseCode.new(dept_name: 'CATALAN', catalog_id: '', dept_code: 'LPSPP', include_in_oec: true),
          Oec::CourseCode.new(dept_name: 'PORTUG', catalog_id: '', dept_code: 'LPSPP', include_in_oec: true),
          Oec::CourseCode.new(dept_name: 'SPANISH', catalog_id: '', dept_code: 'LPSPP', include_in_oec: true),
          Oec::CourseCode.new(dept_name: 'ILA', catalog_id: '', dept_code: 'LPSPP', include_in_oec: false)
        ]
      end
      it { should include(
        "(sec.\"displayName\" LIKE 'CATALAN %'",
        "(sec.\"displayName\" LIKE 'PORTUG %'",
        "(sec.\"displayName\" LIKE 'SPANISH %'"
      ) }
      it 'includes an explicitly selected department even if it is not participating' do
        expect(subject).to include "(sec.\"displayName\" LIKE 'ILA %')"
      end
    end

    context 'limiting query by course code' do
      let(:course_codes) do
        [
          Oec::CourseCode.new(dept_name: 'INTEGBI', catalog_id: '', dept_code: 'IBIBI', include_in_oec: true),
          Oec::CourseCode.new(dept_name: 'BIOLOGY', catalog_id: '1B', dept_code: 'IBIBI', include_in_oec: true),
          Oec::CourseCode.new(dept_name: 'BIOLOGY', catalog_id: '1BL', dept_code: 'IBIBI', include_in_oec: true)
        ]
      end
      it { should include(
        "(sec.\"displayName\" LIKE 'INTEGBI %'",
        "(sec.\"displayName\" = 'BIOLOGY 1B' or sec.\"displayName\" = 'BIOLOGY 1BL')"
      )}
      it { should_not include 'NOT' }
    end
  end

  def expect_results(keys, opts={})
    subject.each do |result|
      if opts[:allow_nil]
        keys.each { |key| expect(result).to have_key key }
      elsif keys.is_a? Hash
        keys.each { |key, value| expect(result[key]).to eq value }
      else
        keys.each { |key| expect(result[key]).to be_present }
      end
    end
  end

  shared_examples 'expected result structure' do
    it 'should return something' do
      expect(subject).to_not be_empty
    end
    it 'should include course catalog data' do
      expect_results(
        %w(section_id course_display_name instruction_format section_num primary enrollment_count),
        allow_nil: false
      )
      expect_results(%w(course_title_short), allow_nil: true)
    end
    it 'should include instructor data' do
      expect_results(%w(ldap_uid sis_id role_code affiliations), allow_nil: true)
    end
    it 'should include ccn subqueries' do
      expect_results(%w(cross_listed_ccns co_scheduled_ccns), allow_nil: true)
    end
  end

  context 'course code lookup', testext: true do
    subject do
      EdoOracle::Oec.get_courses(term_id, EdoOracle::Oec.depts_clause(term_code, course_codes))
    end

    context 'a department participating in OEC' do
      let(:course_codes) do
        [Oec::CourseCode.new(dept_name: 'PORTUG', catalog_id: nil, dept_code: 'LPSPP', include_in_oec: true)]
      end
      include_examples 'expected result structure'
    end

    context 'a department not participating in OEC' do
      let(:course_codes) do
        [Oec::CourseCode.new(dept_name: 'FRENCH', catalog_id: nil, dept_code: 'HFREN', include_in_oec: false)]
      end
      include_examples 'expected result structure'
    end
  end

  context 'course lookup', testext: true do
    let(:course_id_list) { EdoOracle::Oec.chunked_whitelist(EdoOracle::Oec.course_ccn_column, course_ids) }

    context 'lookup by course id' do
      let(:course_ids) { %w(31036 31037) }
      subject { EdoOracle::Oec.get_courses(term_id, course_id_list) }
      include_examples 'expected result structure'
      it 'returns the right courses' do
        expect(subject).to have(2).items
        expect(subject.map { |row| row['section_id'] }).to match_array course_ids
      end
    end

    context 'crosslisting and room share lookup' do
      let(:course_ids) { %w(32821 32862) }
      let(:course_id_aggregates) { [ '32819,32820,32821', '32862,33269,33378' ] }
      subject { EdoOracle::Oec.get_courses(term_id, course_id_list) }
      it 'returns correct aggregated ccns' do
        expect(subject.map { |row| row['cross_listed_ccns'].split(',').uniq.join(',') }).to match_array course_id_aggregates
        expect(subject.map { |row| row['co_scheduled_ccns'].split(',').uniq.join(',') }).to match_array course_id_aggregates
      end
    end
  end
end
